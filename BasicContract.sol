pragma solidity 0.5.16;

interface IBEP20 {

  function totalSupply() external view returns (uint256);
  function decimals() external view returns (uint8);
  function symbol() external view returns (string memory);
  function name() external view returns (string memory);
  function getOwner() external view returns (address);
  function balanceOf(address account) external view returns (uint256);
  function transfer(address recipient, uint256 amount) external returns (bool);
  function allowance(address _owner, address spender) external view returns (uint256);
  function approve(address spender, uint256 amount) external returns (bool);
  function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract Context {
  constructor () internal { }

  function _msgSender() internal view returns (address payable) {
    return msg.sender;
  }

  function _msgData() internal view returns (bytes memory) {
    this;
    return msg.data;
  }
}

library SafeMath {

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a, "SafeMath: addition overflow");

    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    return sub(a, b, "SafeMath: subtraction overflow");
  }

  function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b <= a, errorMessage);
    uint256 c = a - b;

    return c;
  }

  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b, "SafeMath: multiplication overflow");

    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return div(a, b, "SafeMath: division by zero");
  }

  function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b > 0, errorMessage);
    uint256 c = a / b;

    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    return mod(a, b, "SafeMath: modulo by zero");
  }

  function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
    require(b != 0, errorMessage);
    return a % b;
  }
}


contract Ownable is Context {
  address private _owner;

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

  constructor () internal {
    address msgSender = _msgSender();
    _owner = msgSender;
    emit OwnershipTransferred(address(0), msgSender);
  }

  function owner() public view returns (address) {
    return _owner;
  }


  modifier onlyOwner() {
    require(_owner == _msgSender(), "Ownable: caller is not the owner");
    _;
  }

  function renounceOwnership() public onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
  }

  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0), "Ownable: new owner is the zero address");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

contract RealRegularCoin is Context, IBEP20, Ownable {////////////////////////////////////
  using SafeMath for uint256;

  mapping (address => uint256) private _balances;
  mapping (address => mapping (address => uint256)) private _allowances;
  mapping (address => bool) private _isExcludedFromFee; //WhiteList: bool true - whitelisted, false - no
  mapping (address => bool) private _isBlacklisted; //Blacklist: bool true - blacklisted, false - no
  
  uint8 private _decimals;
  uint64 public limitSize;
  uint64 private _limitPeriod;
  
  uint256 private _endOfLimit = 0;
  uint256 private _totalSupply;
  
  string private _symbol;
  string private _name;
  
  address feeReceiver = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2;

  constructor() public {
    _name = "RealRegularCoin";
    _symbol = "XRC";
    _decimals = 18;
    _totalSupply = 1000000000000000000000000;
    _balances[msg.sender] = 1000000000000000000000000;
    _isExcludedFromFee[msg.sender] = true;

    emit Transfer(address(0), msg.sender, _totalSupply);
  }

  function getOwner() external view returns (address) {
    return owner();
  }

  function decimals() external view returns (uint8) {
    return _decimals;
  }

  function symbol() external view returns (string memory) {
    return _symbol;
  }

  function name() external view returns (string memory) {
    return _name;
  }

  function totalSupply() external view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) external view returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) external isBlacklisted(msg.sender) returns (bool) {
    _transfer(_msgSender(), recipient, amount); //!!!!!!!
    return true;
  }

  function allowance(address owner, address spender) external view isBlacklisted(msg.sender) returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) external isBlacklisted(msg.sender) returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) external isBlacklisted(msg.sender) returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
    return true;
  }

  function increaseAllowance(address spender, uint256 addedValue) public isBlacklisted(msg.sender) returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
    return true;
  }

  function decreaseAllowance(address spender, uint256 subtractedValue) public isBlacklisted(msg.sender) returns (bool) {
    _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero"));
    return true;
  }

  function mint(uint256 amount) public onlyOwner returns (bool) {
    _mint(_msgSender(), amount);
    return true;
  }

  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), "BEP20: transfer from the zero address");
    require(recipient != address(0), "BEP20: transfer to the zero address");
    
    if (_isExcludedFromFee[sender] == true)  { 
        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
    }
    else {
         _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
         _balances[recipient] = _balances[recipient].add(amount - amount.mul(8).div(100));
         _balances[feeReceiver] = _balances[feeReceiver].add(amount- amount.mul(98).div(100));
    }
    
    emit Transfer(sender, recipient, amount);
  }

  function _mint(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: mint to the zero address");

    _totalSupply = _totalSupply.add(amount);
    _balances[account] = _balances[account].add(amount);
    emit Transfer(address(0), account, amount);
  }

  function _burn(address account, uint256 amount) internal {
    require(account != address(0), "BEP20: burn from the zero address");

    _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");
    _totalSupply = _totalSupply.sub(amount);
    emit Transfer(account, address(0), amount);
  }

  function _approve(address owner, address spender, uint256 amount) internal {
    require(owner != address(0), "BEP20: approve from the zero address");
    require(spender != address(0), "BEP20: approve to the zero address");

    _allowances[owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _burnFrom(address account, uint256 amount) internal {
    _burn(account, amount);
    _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "BEP20: burn amount exceeds allowance"));
  }
  
  function addToBlacklist(address account) public onlyOwner {
    _isBlacklisted[account] = true;
  }
  
  function addToWhitelist(address account) public onlyOwner {
      _isExcludedFromFee[account] = true;
  }
  
  function delFromBlackList(address account) public onlyOwner {
      _isBlacklisted[account] = false;
  }
  
  function delFromWhiteList(address account) public onlyOwner {
      _isExcludedFromFee[account] = false;
  }
  
  function getInfoBlackWhiteLists(address sender) public view returns(bool, bool)
  {
      return (_isBlacklisted[sender], _isExcludedFromFee[sender]);
  }
  
  function setLimit(uint64 _limitSize, uint64 __limitPeriod) public onlyOwner { //limitPeriod передается в часах и переводится в секунды
      limitSize = _limitSize; //размер лимита токенов в нативной валюте
      _limitPeriod = __limitPeriod * 3600; //время действия ограничений
      _endOfLimit = block.timestamp + _limitPeriod; 
  }
  
  function whenTheLimitEnd() view public returns(uint256) { //публичная функция, которая возвращает количество секунд до конца лимита
      require(_endOfLimit > block.timestamp, "There are no limits now!");
      return _endOfLimit - block.timestamp;
  }
  
  modifier isBlacklisted(address sender) {
    require(!_isBlacklisted[sender], "You cannot do this because you are blacklisted!");
    _;
  }
}
