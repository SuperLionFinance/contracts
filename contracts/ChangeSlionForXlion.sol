pragma solidity 0.6.12;

import './lib/SafeMath.sol';
import './lib/IBEP20.sol';
import './lib/SafeBEP20.sol';
import './lib/Ownable.sol';
import "./lib/ReentrancyGuard.sol";

import "./XlionToken.sol";

contract ChangeSlionForXlion is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IBEP20 lpToken;
    }

    // The XLION TOKEN!
    XlionToken public xlion;

    uint256 public xlionPerSlion;

    uint256 public maxSlionInDeposit;

    uint256 public slionDeposited;
    uint256 public xlionCollected;

    PoolInfo[] public poolInfo;
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;

    uint256 public lastBlockToDepositSlion;
    uint256 public firstBlockToWithdraw;

    event DepositSlion(address indexed user, uint256 indexed pid, uint256 amount);
    event CollectXlion(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        XlionToken _xlion,
        IBEP20 _slion,
        uint256 _xlionPerSlion,
        uint256 _maxSlionInDeposit,
        uint256 _lastBlockToDepositSlion,
        uint256 _firstBlockToWithdraw
    ) public {
        xlion = _xlion;
        xlionPerSlion = _xlionPerSlion;
        maxSlionInDeposit = _maxSlionInDeposit;
        lastBlockToDepositSlion = _lastBlockToDepositSlion;
        firstBlockToWithdraw = _firstBlockToWithdraw;

        slionDeposited = 0;
        xlionCollected = 0;

        // staking pool
        poolInfo.push(PoolInfo({
            lpToken: _slion
        }));
    }

    function getSlionDeposited() external view returns (uint256) {
        return slionDeposited;
    }

    function getXlionCollected() external view returns (uint256) {
        return xlionCollected;
    }

    function getPendingXlionByUser(uint256 _pid, address _user) external view returns (uint256) {
        UserInfo storage user = userInfo[_pid][_user];
        return user.rewardDebt;
    }

    function depositSlion(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(_amount > 0, "depositSlion: not good");
        require(block.number < lastBlockToDepositSlion, "depositSlion: current block is higher than lastBlockToDepositSlion");
        require(slionDeposited.add(_amount) <= maxSlionInDeposit);

        //pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        pool.lpToken.safeTransferFrom(address(msg.sender), address(0x00dead), _amount);

        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(xlionPerSlion).div(1e18);

        slionDeposited = slionDeposited.add(_amount);

        emit DepositSlion(msg.sender, _pid, _amount);
    }

    function collectXlion(uint256 _pid) public nonReentrant {
        UserInfo storage user = userInfo[_pid][msg.sender];

        require(user.amount > 0, "collectXlion: not good");
        require(block.number > firstBlockToWithdraw, "depositSlion: current block is higher than lastBlockToDepositSlion");

        emit CollectXlion(msg.sender, _pid, user.rewardDebt);

        safeXlionTransfer(msg.sender, user.rewardDebt);
        user.rewardDebt = 0;

        xlionCollected = xlionCollected.add(user.rewardDebt);
    }

    function safeXlionTransfer(address _to, uint256 _amount) internal {
        uint256 xlionBalance = xlion.balanceOf(address(this));
        if (_amount > xlionBalance) {
            xlion.transfer(_to, xlionBalance);
        } else {
            xlion.transfer(_to, _amount);
        }
    }
}