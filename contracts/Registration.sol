// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/security/ReentrancyGuard.sol";

abstract contract Registration is ReentrancyGuard {
  using SafeMath for uint256;

  uint256 public constant MINING_PERIOD = 30 days;

  mapping(address => uint256) public _balances;
  mapping(address => uint256) public _releases;
  mapping(address => uint256) public _nextRewards;

  struct Distribution {
    address account;
    uint256 time;
    uint256 amount;
    uint256 value;
  }

  Distribution[] public _failedDistributions;
  Distribution[] public _distributions;

  event Registered(address indexed account, uint256 value);
  event Refunded(address indexed account, uint256 value, string reason);
  event BnbWithdrawn(address indexed account, uint256 amount);

  /**
   * @dev Returns the received BNB to the sender
   */
  function _refund(string memory reason) internal {
    Distribution memory fail;

    fail.account = msg.sender;
    fail.time = block.timestamp; // solhint-disable-line
    fail.value = msg.value;

    _failedDistributions.push(fail);

    address payable you = payable(msg.sender);
    you.transfer(msg.value);

    emit Refunded(msg.sender, msg.value, reason);
  }

  /**
   * Registers and adds the user to the liquidity miners' list
   */
  function _register() internal {
    _balances[msg.sender] = msg.value;
    _releases[msg.sender] = block.timestamp.add(MINING_PERIOD); // solhint-disable-line
    _nextRewards[msg.sender] = block.timestamp; // solhint-disable-line

    emit Registered(msg.sender, msg.value);
    mine();
  }

  /**
   * Transfers the staked BNB back to the sender
   */
  function _withdraw() internal {
    address payable you = payable(msg.sender);
    uint256 yourStake = _balances[msg.sender];

    _balances[msg.sender] = 0;
    you.transfer(yourStake);
    emit BnbWithdrawn(msg.sender, yourStake);
  }

  function mine() public virtual;
}
