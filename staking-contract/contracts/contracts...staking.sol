// SPDX-License-Identifier: Unlicensed
pragma solidity > 0.4.0 < 0.9.0;

import "./token.sol";

contract Staking is Ownable {
    using SafeMath for uint256;

    Token public token;

    //defaults
    bool public isDisabled = false;
    uint256 public totalValueLocked = 0;
    uint256 public rewardPercentage = 10; //percentage
    uint256 public stakingPeriod = 90; //in days

    //mapping
    mapping (address => uint256) public stakerBalance;
    mapping(address => uint256) public timeLastStaked;

    //events
    event staked (address indexed staker, uint256 amount);
    event unstaked (address indexed staker, uint256 amount);
    event claimed(address indexed staker, uint256 amount);
    event completedStaking(address indexed staker, bool  hasCompleted);
    
    constructor (Token _token) {
        token = _token;
    }

    modifier onlyStaker () {
        require(stakerBalance[msg.sender] > 0, "Insufficient balance");
        _;
    }

    function stake (uint256 _amount) public {
        require (!isDisabled, "Staking is currently disabled");
        require (_amount > 0, "amount should be more than 0");

        token.transferFrom(msg.sender, address(this), _amount);
        totalValueLocked = totalValueLocked.add(_amount); //updates TVL

        stakerBalance[msg.sender] = stakerBalance[msg.sender].add(_amount); //updates stakerBalance after staking
        timeLastStaked[msg.sender] = block.timestamp; //updates the last time staked

        emit staked(msg.sender, stakerBalance[msg.sender]);
    }

    function unstake () public onlyStaker {
        require(!checkStakingCompleted(msg.sender), "Staking period completed, claim your rewards");
        uint256 balance = stakerBalance[msg.sender];
        address recipent = payable (msg.sender);

        token.transfer(recipent, balance);
        totalValueLocked = totalValueLocked.sub(balance); //updates TVL

        emit unstaked(recipent, balance);

        stakerBalance[msg.sender] = 0; //updates stakerBalance after unstaking
    }

    function claim () public onlyStaker {
        require(checkStakingCompleted(msg.sender), "No rewards to claim");
        // TODO
    }

    //check if staker has completed the staking period
    function checkStakingCompleted(address _staker) internal returns(bool){
        address staker = _staker;
        uint256 timeRequired = timeLastStaked[msg.sender].add(stakingPeriod.mul(1));

        if(block.timestamp > timeRequired){
            emit completedStaking(staker, true);
            return true;
        } else {
            return false;
        }
    }

    function updateDisableStaking(bool _isDisabled) public onlyOwner{
        isDisabled = _isDisabled;
    }

// ! ======================= TESTING FUNCTIONS ==========================!
    function changeAPY (uint256 _newValue) public onlyOwner{
        require(_newValue >= 0 && _newValue <= 100, "The new APY must be between 0 and 100");
        rewardPercentage = _newValue;
    }

    function changePeriod(uint256 _newPeriod) public onlyOwner{
        require(_newPeriod > 0, "new period must be more than 0" );
        stakingPeriod = _newPeriod;
    }

    function getTVL() internal view returns (uint256){
        return totalValueLocked;
    }
}