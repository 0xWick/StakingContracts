// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;

    // Admin Controls
    uint public rewardsPerHour = 100000; // 0.01%

    uint public withdrawTax = 25; // 2.5% during calculations

    address public treasuryWallet;

    uint public stakeBalance = 0;

    event Deposit(address sender, uint amount);
    event Withdraw(address sender, uint amount);
    event Claim(address sender, uint amount);
    event Compound(address sender, uint amount);

    mapping(address => uint) public balanceOf;
    mapping(address => uint) public lastUpdated;
    mapping(address => uint) public claimed;

    constructor(IERC20 token_, address _treasuryWalletAddress) {
        token = token_;

        treasuryWallet = _treasuryWalletAddress;
    }

    function rewardBalance() external view returns (uint) {
        return _rewardBalance();
    }

    function _rewardBalance() internal view returns (uint) {
        return token.balanceOf(address(this)) - stakeBalance;
    }

    function deposit(uint amount_) external {
        _deposit(amount_);
    }

    function _deposit(uint amount_) internal {
        token.safeTransferFrom(msg.sender, address(this), amount_);
        balanceOf[msg.sender] += amount_;
        lastUpdated[msg.sender] = block.timestamp;
        stakeBalance += amount_;
        emit Deposit(msg.sender, amount_);
    }

    function rewards(address address_) external view returns (uint) {
        return _rewards(address_);
    }

    function _rewards(address address_) internal view returns (uint) {
        return (block.timestamp - lastUpdated[address_]) * balanceOf[address_] / (rewardsPerHour * 1 seconds);
    }

    // Set Reward Rate
    function setRewardPerHour(uint _newRewardsPerHour) external onlyOwner {
        rewardsPerHour = _newRewardsPerHour;
    }

    function claim() external {
        uint amount = _rewards(msg.sender);
        token.safeTransfer(msg.sender, amount);
        _update(amount);
        emit Claim(msg.sender, amount);
    }

    function _update(uint amount_) internal {
        claimed[msg.sender] += amount_;
        lastUpdated[msg.sender] = block.timestamp;
    }

    function compound() external {
        _compound();
    }

    function _compound() internal {
        uint amount = _rewards(msg.sender);
        balanceOf[msg.sender] += amount;
        stakeBalance += amount;
        _update(amount);
        emit Compound(msg.sender, amount);
    }

    function withdraw(uint amount_) external {
        require(balanceOf[msg.sender] >= amount_, "Insufficient funds");

        _compound();
        balanceOf[msg.sender] -= amount_;
        stakeBalance -= amount_;

        // Define the withdrawal tax rate
        uint taxAmount = (amount_ * withdrawTax) / 1000; // 3.5% of the withdrawal amount

        // Transfer the Tax to the Treasury
        token.safeTransferFrom(msg.sender, treasuryWallet, taxAmount);
        
        // Transfer the rest to the User
        token.safeTransfer(msg.sender, amount_ - taxAmount);

        emit Withdraw(msg.sender, amount_);
    }

}
