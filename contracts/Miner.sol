// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "./Registration.sol";

/**
 * @title BNB Liquidity Mining
 * @dev The BNB liquidity mining contract rewards
 * BNB staker with free NEP tokens.
 *
 * At the end of the mining period (see `MINING_PERIOD`), the staked BNB
 * is returned to the sender.
 *
 * During the mining period, the stakers can withdraw daily NEP rewards.
 * If not withdrawn, the rewards do not carry forward or accumulate.
 */
contract Miner is Registration {
  using SafeMath for uint256;

  uint256 public constant MAX = 1100000000 gwei; // 1.1 BNB

  uint256 public immutable _startDate;
  uint256 public immutable _finalizationDate;
  uint256 public immutable _maximumBnb;
  uint256 public immutable _rewardAmount;
  address public immutable _creator;
  IERC20 public immutable _nepToken;

  event NepMined(address indexed account, Distribution distribution);

  constructor(
    IERC20 nep,
    uint256 startDate,
    uint256 finalizationDate,
    uint256 maxBNB,
    uint256 rewardAmount
  ) {
    _nepToken = nep;
    _startDate = startDate;
    _finalizationDate = finalizationDate;
    _maximumBnb = maxBNB;
    _rewardAmount = rewardAmount;

    _creator = msg.sender;
  }

  /**
   * @dev Accepts incoming BNB only if
   *
   * 1. The campaign is active (during start and finish dates)
   * 2. The sent amount is less than the max BNB value
   * 3. The NEP balance of this contract is greater than zero
   * 4. The BNB balance of this contract is less than the cap
   * 5. The sender is not already registered
   *
   * Refunds the received BNB is the request is invalid.
   *
   * @notice The received BNB can only be withdrawn by the sender not the contract owner.
   */
  receive() external payable {
    if (block.timestamp < _startDate) {
      // solhint-disable-previous-line
      return super._refund("This campaign hasn't started yet");
    }

    if (block.timestamp > _finalizationDate) {
      // solhint-disable-previous-line
      return super._refund("The campaign is already over");
    }

    if (msg.value > MAX) {
      return super._refund("The amount is too high");
    }

    if (_nepToken.balanceOf(address(this)) == 0) {
      return super._refund("The airdrop is closed");
    }

    if (address(this).balance >= _maximumBnb) {
      return super._refund("The target was already reached");
    }

    if (_balances[msg.sender] > 0) {
      return super._refund("You are already registered");
    }

    super._register();
  }

  /**
   * @dev Mines your reward on a daily basis
   */
  function mine() public override nonReentrant {
    uint256 nextRewardOn = _nextRewards[msg.sender];
    uint256 contractBalance = _nepToken.balanceOf(address(this));

    // Prevent double daily rewards
    if (block.timestamp < nextRewardOn) {
      // solhint-disable-previous-line
      return;
    }

    // The contract does not have sufficient balance
    if (contractBalance < _rewardAmount) {
      return;
    }

    _nextRewards[msg.sender] = block.timestamp.add(1 days); // solhint-disable-line

    Distribution memory distribution;

    distribution.account = msg.sender;
    distribution.time = block.timestamp; // solhint-disable-line
    distribution.amount = _rewardAmount;

    _distributions.push(distribution);

    _nepToken.transfer(msg.sender, _rewardAmount);

    emit NepMined(msg.sender, distribution);
  }

  /**
   * @dev Allows you to withdraw your staked BNB balance
   * after the `MINING_PERIOD`
   */
  function withdrawBNB() external nonReentrant {
    if (block.timestamp < _releases[msg.sender]) {
      // solhint-disable-previous-line
      return; // You're early
    }

    if (_balances[msg.sender] == 0) {
      return; // You don't have any balance or you've already withdrawn
    }

    super._withdraw();
  }

  /**
   * @dev Finalizes the contract to withdraw remaining NEP tokens if any
   * to distribte them on future rounds
   */
  function finalize() external {
    if (msg.sender != _creator) {
      return;
    }

    if (block.timestamp < _finalizationDate) {
      // solhint-disable-previous-line
      return;
    }

    uint256 dust = _nepToken.balanceOf(address(this));
    _nepToken.transfer(msg.sender, dust);
  }
}
