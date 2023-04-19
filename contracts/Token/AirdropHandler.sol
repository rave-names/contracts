// SPDX-License-Identifier: Unlisence
pragma solidity ^0.8.19;

// import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {NumberUtils} from "../Other/NumberUtilities.sol";
import "hardhat/console.sol";

contract AirdropHandler is OwnableUpgradeable, UUPSUpgradeable {
    ERC20 rave;
    bytes32 root;
    address constant treasury = 0x87f385d152944689f92Ed523e9e5E9Bd58Ea62ef;
    uint claimLimit;

    uint256 constant factor = 5;

    using NumberUtils for uint256;

    event StartLock(address indexed account, uint amount);

    struct Lock {
        uint unlockTime;
        uint amount;
        uint ftmUnlockTime;
        bool active;
        bool ftmClaimed;
    }

    mapping(address claimer => Lock lock) locks;
    mapping(address claimer => bool claimed) claimed;

    // post-initial-deploy
    uint constant claimOffset = 2 weeks;
    uint private _totalSupply;

    function initialize(address _rave, bytes32 _root) public initializer {
        __Ownable_init_unchained();
        rave = ERC20(_rave);
        root = _root;
        claimLimit = block.timestamp + 2.5 weeks;
    }

    function startLock(
        uint256 _amount,
        bytes32[] calldata merkleProof
    ) public payable {
        address account = msg.sender;

        require(block.timestamp < 1682899200, "You are too late");

        require(
            msg.value >= 5,
            "You need to lock 5 FTM to start an airdrop lock"
        );

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(account, _amount));
        require(MerkleProof.verify(merkleProof, root, node), "Invalid proof.");

        require(!claimed[account], "Already claimed.");

        claimed[account] = true;

        locks[account] = Lock({
            //          feb 14 2023 + 4 yrs
            unlockTime: 1676293200 + 208 weeks,
            amount: _amount.clamp(0, 200_000),
            // 4 months
            ftmUnlockTime: block.timestamp + 10518972,
            active: true,
            ftmClaimed: false
        });

        _totalSupply += (_amount * factor) / 100;

        emit StartLock(account, _amount);
    }

    function claimFTM() public {
        address account = msg.sender;

        require(
            block.timestamp >= locks[account].ftmUnlockTime,
            "You cannot claim your FTM yet."
        );

        require(
            !locks[account].ftmClaimed,
            "You have already claimed your FTM."
        );

        require(claimed[account]);

        (bool success, ) = account.call{value: 5e18}("");

        require(success, "Transfer failed.");

        locks[account].ftmClaimed = true;
    }

    function claimRAVE() external {
        address account = msg.sender;

        require(
            block.timestamp >= locks[account].unlockTime,
            "You cannot claim your RAVE yet."
        );
        require(locks[account].active, "This lock is inactive.");

        require(claimed[account]);

        if (!locks[account].ftmClaimed) claimFTM();

        rave.transfer(
            account,
            (locks[account].amount.toDecimals(18) * factor) / 100
        );

        locks[account].active = false;
    }

    function earlyUnlock() external {
        address account = msg.sender;

        require(claimed[account]);
        require(locks[account].active, "This lock is inactive.");

        require(
            block.timestamp <= locks[account].unlockTime,
            "You can claim your RAVE normally."
        );

        uint startTime = locks[account].unlockTime - 208 weeks;
        uint timeLocked = block.timestamp - startTime;

        uint raveToSend = (locks[account].amount * timeLocked) / 208 weeks;

        rave.transfer(account, raveToSend.toDecimals(18));

        rave.transfer(
            treasury,
            (locks[account].amount - raveToSend).toDecimals(18)
        );

        if (!locks[account].ftmClaimed) {
            (bool success, ) = account.call{value: 5e18}("");

            require(success, "Sending FTM Failed.");

            locks[account].ftmClaimed = true;
        }

        locks[account].active = false;
    }

    function lock(address owner) external view returns (Lock memory, bool) {
        return (locks[owner], claimed[owner]);
    }

    function balanceOf(address owner) external view returns (uint256) {
        return locks[owner].amount;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function decimals() public pure returns (uint256) {
        return 0;
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function sendFTM() external payable {}
}
