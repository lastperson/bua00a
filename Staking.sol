// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

interface IERC20 {
    function transfer(address to, uint amount) external;
    function transferFrom(address payer, address to, uint amount) external;
}

contract Staking {
    IERC20 immutable public stakingToken;
    address immutable public owner;
    uint constant public FREEZE_TIME = 1 days;

    struct User {
        uint stake;
        uint pendingUnstake;
        uint unstakeDate;
    }
    struct Database {
        mapping(address => User) users;
        uint unstakeFee;
    }

    Database db;

    event Stake(address user, uint amount);
    event Unstake(address user, uint amount);

    constructor(IERC20 token) {
        stakingToken = token;
        owner = msg.sender;
    }

    function stake(uint amount) external {
        stakingToken.transferFrom(msg.sender, address(this), amount);
        User storage user = db.users[msg.sender];
        uint newStake = user.stake + amount;
        user.stake = newStake;
        emit Stake(msg.sender, amount);
    }

    function requestUnstake(uint amount) external {
        User storage user = db.users[msg.sender];
        require(user.stake >= amount, 'Amount is greater than stake');
        require(amount >= db.unstakeFee, 'Amount is less than fee');
        uint newStake = user.stake - amount;
        user.stake = newStake;
        user.pendingUnstake = amount - db.unstakeFee;
        user.unstakeDate = block.timestamp + FREEZE_TIME;
        stakingToken.transfer(owner, db.unstakeFee);
    }

    function unstake() external {
        User storage user = db.users[msg.sender];
        require(passed(user.unstakeDate), 'Cannot unstake yet');
        uint amount = user.pendingUnstake;
        require(amount > 0, 'Unstake is not requested');
        user.pendingUnstake = 0;
        user.unstakeDate = 0;
        stakingToken.transfer(msg.sender, amount);
    }

    function setFee(uint fee) external {
        require(msg.sender == owner, 'Access denied');
        db.unstakeFee = fee;
    }

    function passed(uint date) internal view returns(bool) {
        return block.timestamp > date;
    }
}
