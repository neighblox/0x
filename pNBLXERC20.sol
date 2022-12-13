// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract pNBLX is ERC20, AccessControl, Ownable {

    string private _name = "Pre NBLX";
    string private _symbol = "pNBLX";
    uint8 private constant _decimals = 18;
    uint256 private _totalSupply = 200000 * 10 ** 18;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint)) allowed;

    constructor()
    ERC20(_name, _symbol)
    Ownable()
    {
        _mint(owner(), _totalSupply);
        balances[owner()] = _totalSupply;
        _setupRole(DEFAULT_ADMIN_ROLE, owner());
        _setupRole(BURNER_ROLE, owner());
    }

    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)){
        require(_msgSender() == owner(), "Only admin can grant Role");
        super.grantRole(role, account);
    }

    function hasRoles(bytes32 _role, address _account) public view returns (bool) {
        return (super.hasRole(_role, _account));

    }

    function allowance(address owner, address spender) public view virtual override returns (uint256){
        return super.allowance(owner, spender);
    }

    function approve(address spender, uint256 amount) public virtual override
    onlyOwner returns (bool){
        super.approve(spender, amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual override
    onlyOwner returns (bool){
        super.increaseAllowance(spender, addedValue);
        return true;

    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override onlyOwner
    returns (bool){
        super.decreaseAllowance(spender, subtractedValue);
        return true;
     }

     function totalSupply()public view virtual override returns (uint256) {
        return super.totalSupply();
     }

     function transferFrom(address owner, address buyer, uint numTokens) public override onlyOwner returns (bool) {
        require(numTokens <= balances[owner]);
        allowed[owner][msg.sender] = allowed[owner][msg.sender] - numTokens;
        balances[owner] = balances[owner] -= numTokens;
        balances[buyer] = balances[buyer] += numTokens;
        emit Transfer(owner, buyer, numTokens);
        return true;
    }

}

//access_control
// role_set: minter role, burner role
