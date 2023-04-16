pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "../Other/NumberUtilities.sol";

contract RAVE is ERC20, ERC20Snapshot, Ownable {
    using NumberUtils for uint256;
    address public immutable treasury;
    mapping(address => bool) private snapshotters;
    mapping(address => bool) private admins;
    bytes32 public immutable merkleRoot;
    mapping(address => bool) private claimed;

    event Claimed(address account, uint amount);

    modifier onlyAdmin() {
        // only allow people with the admin role to execute these functions
        require(admins[msg.sender], "RAVE: Not treasury");

        _;
    }

    function _mintDecimals(address account, uint256 amount) internal virtual {
        _mint(account, amount.toDecimals(18));
    }

    function mint(uint amount) external onlyAdmin {
        _mintDecimals(treasury, amount);
    }

    function _mint(
        address account,
        uint256 amount
    ) internal virtual override(ERC20) {
        require(
            ERC20.totalSupply() + amount <= uint(100_000_000).toDecimals(18),
            "ERC20Capped: cap exceeded"
        );
        super._mint(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function snapshot() external {
        require(snapshotters[msg.sender], "Not Allowed");
        _snapshot();
    }

    function addSnapshotter(address snapshotter) external onlyAdmin {
        snapshotters[snapshotter] = true;
    }

    function addAdmin(address admin) external onlyAdmin {
        admins[admin] = false;
    }

    function removeSelf() external onlyAdmin {
        snapshotters[msg.sender] = false;
        admins[msg.sender] = false;
    }

    function isClaimed(address account) external view returns (bool) {
        return claimed[account];
    }

    function claim(
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) public {
        if (msg.sender != owner()) {
            // 14th feb 2023
            require(block.timestamp > 1676329200, "Airdrop hasn't opened yet.");
            // 28th feb 2023
            require(block.timestamp < 1677538800, "Airdrop has closed.");
        }

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(account, amount));
        require(
            MerkleProof.verify(merkleProof, merkleRoot, node),
            "Invalid proof."
        );
        require(!claimed[account], "Already claimed.");

        claimed[account] = true;
        _transfer(address(this), account, amount.toDecimals(18));

        emit Claimed(account, amount);
    }

    function mintToSelf(uint amt) external onlyAdmin {
        require(block.timestamp < 1676329200, "Airdrop already opened.");
        _mintDecimals(address(this), amt);
    }

    function _recoverAirdropFunds() external onlyAdmin {
        require(block.timestamp > 1677538800, "Airdrop hasn't closed yet.");
        transferFrom(address(this), treasury, balanceOf(address(this)));
    }

    constructor(
        address _treasury,
        bytes32 root,
        address dev
    ) ERC20("Rave Names", "RAVE") {
        treasury = _treasury;
        merkleRoot = root;
        snapshotters[dev] = true;
        admins[dev] = true;
    }
}
