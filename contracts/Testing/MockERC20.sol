import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(uint amount, address to) ERC20("Mock", "MOCK") {
        _mint(to, amount);
    }
}
