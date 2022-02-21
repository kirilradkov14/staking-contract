// SPDX-License-Identifier: Unlicensed
pragma solidity > 0.4.0 < 0.9.0;

import "./token.sol";

contract Staking is Ownable {
    using SafeMath for uint256;

    Token public token;

    //defaults
    uint256 public totalValueLocked = 0;
    uint256 public rewardRate = 10; //percentage
    uint256 public stakingPeriod = 90; //in days
    bool public isAvailable = true;

    //mapping
    mapping (address => uint256) public stakerBalance;
    mapping(address => uint256) public timeLastStaked;
    mapping(address => uint256) public claimableRewards;

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

    modifier onlyAvailable () {
        require(isAvailable);
        _;
    }

    function stake (uint256 _amount)  public onlyAvailable {
        require (_amount > 0, "Invalid amount");

        token.transferFrom(msg.sender, address(this), _amount);
        totalValueLocked = totalValueLocked.add(_amount); //updates TVL

        stakerBalance[msg.sender] = stakerBalance[msg.sender].add(_amount); //updates stakerBalance after staking
        timeLastStaked[msg.sender] = block.timestamp; //updates the last time staked

        emit staked(msg.sender, stakerBalance[msg.sender]);

        claimableRewards[msg.sender] = (stakerBalance[msg.sender].mul(rewardRate)).div(100);
    }

    function unstake () public onlyStaker {
        require(!checkStakingCompleted(msg.sender), "Staking period completed, claim your rewards");
        
        uint256 balance = stakerBalance[msg.sender];
        address recipent = payable (msg.sender);

        token.transfer(recipent, balance);
        totalValueLocked = totalValueLocked.sub(balance); //updates TVL

        emit unstaked(recipent, balance);

        claimableRewards[msg.sender] = 0;
        stakerBalance[msg.sender] = 0;
    }

    function claim () public onlyStaker {
        require(checkStakingCompleted(msg.sender), "No rewards to claim");

        address recipent = payable (msg.sender);
        uint256 balance = stakerBalance[msg.sender];
        uint256 rewards = claimableRewards[msg.sender];

        // if not enough tokens in contract to distribute rewards, send the balance
        uint256 contractBalance = token.balanceOf(address(this));
        if (contractBalance >= (totalValueLocked.add(claimableRewards[msg.sender]))){
            token.transfer(recipent, balance.add(rewards));
            totalValueLocked = totalValueLocked.sub(balance.add(rewards));

            emit claimed(recipent, rewards);
            emit unstaked(recipent, balance);
        } else {
            token.transfer(recipent, balance);
            totalValueLocked = totalValueLocked.sub(balance);
            
            emit unstaked(recipent, balance);
        }

        claimableRewards[msg.sender] = 0;
        stakerBalance[msg.sender] = 0;
    }

    //check if staker has completed the staking period
    function checkStakingCompleted(address _staker) internal returns(bool){
        address staker = _staker;
        uint256 timeRequired = timeLastStaked[msg.sender].add(stakingPeriod.mul(1)); // 86400 for 1 day

        if(block.timestamp > timeRequired){
            emit completedStaking(staker, true);
            return true;
        } else {
            return false;
        }
    }

    function disableStaking (bool _isAvailable) private onlyOwner{
        isAvailable = _isAvailable;
    }

// ! ======================= TESTING FUNCTIONS ==========================!
    function changeAPY (uint256 _newValue) public onlyOwner{
        require(_newValue >= 0 && _newValue <= 100, "The new APY must be between 0 and 100");
        rewardRate = _newValue;
    }

    function changePeriod(uint256 _newPeriod) public onlyOwner{
        require(_newPeriod > 0, "new period must be more than 0" );
        stakingPeriod = _newPeriod;
    }

    function getContractBalance () public view returns (uint256){
        uint256 contractBalance = token.balanceOf(address(this));
        return contractBalance;
    }

    function getRewardBalance () public view returns (uint256){
        uint256 rewardBalance = token.balanceOf(address(this)).sub(totalValueLocked);
        return rewardBalance;
    }

    function getStakerRewards (uint256 _amount) public view returns (uint256){
        uint256 stakerRewards = (_amount.mul(rewardRate)).div(100);
        return stakerRewards;
    }
}
