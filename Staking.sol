// SPDX-License-Identifier: Unlicensed
pragma solidity > 0.4.0 < 0.9.0;

import "./Token.sol";

contract Staking is Ownable {
    using SafeMath for uint256;

    Token public token;

    //declare default values: isAvailable, apy, period, TVL
    bool public isAvailable = true;
    uint256 public rewardRate = 10;
    uint256 public stakingPeriod = 90;
    uint256 public totalValueLocked = 0;

    //a struct to store stakedAmount, timeLastStaked, claimableRewards
    struct Staker {
        uint256 stakedAmount;
        uint256 claimableRewards;
        uint256 timeLastStaked;
    }

    //mapping address => struct
    mapping (address => Staker) public stakers;

    //events
    event staked (address indexed staker, uint256 amount);
    event unstaked (address indexed staker, uint256 amount);
    event claimed(address indexed staker, uint256 amount);

    constructor (Token _token) {
        token = _token;
    }

    //modifiers
    modifier onlyStaker () {
        require(stakers[msg.sender].stakedAmount > 0, "Caller is not a staker.");
        _;
    }
    modifier onlyAvailable () {
        require(isAvailable, "Staking Program not currently available.");
        _;
    }
    modifier onlyClaimable () {
        require(block.timestamp > stakers[msg.sender].timeLastStaked.add(stakingPeriod.mul(1)), "Staking Period is not over yet.");
        _;
    }
    modifier onlyEnoughBalance () {
        require (token.balanceOf(address(this)) >= totalValueLocked.add(stakers[msg.sender].claimableRewards), "Not enough contract balance for rewards");
        _;
    }

    //stake function
    function stake (uint256 _amount) external onlyAvailable onlyEnoughBalance {
        require(_amount > 0, "Amount must exceed 0.");

        //stake
        token.transferFrom(msg.sender, address(this), _amount);

        // store the staked amount, calculate and store the rewards, get the time of staking
        stakers[msg.sender].stakedAmount = stakers[msg.sender].stakedAmount.add(_amount);
        stakers[msg.sender].claimableRewards = ((stakers[msg.sender].stakedAmount).mul(rewardRate)).div(100);
        stakers[msg.sender].timeLastStaked = block.timestamp;

        //update TVL
        totalValueLocked = totalValueLocked.add(_amount);

        emit staked(msg.sender, _amount);
    }

    //unstake function
    function unstake (uint256 _amount) external onlyStaker {
        require(_amount > 0, "Amount must exceed 0.");

        //unstake
        token.transfer(msg.sender, _amount);

        //update the staked amount, calculate and store the rewards
        stakers[msg.sender].stakedAmount = stakers[msg.sender].stakedAmount.sub(_amount);
        stakers[msg.sender].claimableRewards = ((stakers[msg.sender].stakedAmount).mul(rewardRate)).div(100);

        //update TVL
        totalValueLocked = totalValueLocked.sub(_amount);

        emit unstaked(msg.sender, _amount);
    }

    //claim function
    function claim () external onlyStaker onlyClaimable onlyEnoughBalance{

        //claim + unstake
        token.transfer(msg.sender, stakers[msg.sender].claimableRewards.add(stakers[msg.sender].stakedAmount));

        //update TVL
        totalValueLocked = totalValueLocked.sub(stakers[msg.sender].stakedAmount);

        //null balances
        stakers[msg.sender].stakedAmount = 0;
        stakers[msg.sender].claimableRewards = 0;

        emit claimed(msg.sender, stakers[msg.sender].claimableRewards);
        emit unstaked(msg.sender, stakers[msg.sender].stakedAmount);
    }


    //update status
    function updateStatus() external onlyOwner {
        if (isAvailable) {
            isAvailable = false;
        } else {
            isAvailable = true;
        }
    }

    //update period
    function udpatePeriod (uint256 _newPeriod) external onlyOwner {
        require(_newPeriod != stakingPeriod && _newPeriod >= 0, "Invalid param.");

        stakingPeriod = _newPeriod;
    }

    //update returns
    function changeAPY (uint256 _newRate) external onlyOwner {
        require(_newRate != rewardRate && _newRate >=0, "Invalid param.");

        rewardRate = _newRate;
    }
}



