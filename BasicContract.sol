// SPDX-License-Identifier: MIT
pragma solidity 0.6.6;

import './Context.sol';
import './IBEP20.sol';
import './SafeMath.sol';
import './Ownable.sol';
import './PancakeRouter.sol';


contract RealRegularCoin is Context, IBEP20, Ownable { 
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
  address XRCtoken = 0xFFC6C96240BA79c80e74142b2dAF40a3Ea9Fc663;
  address BNBtoken = 0xB8c77482e45F1F44dE1745F52C74426C631bDD52;
  IPancakeRouter02  public immutable pancakeRouter02;
  

  constructor() public {
    IPancakeRouter02 _pancakeRouter02 = IPancakeRouter02((payable)0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
    pancakeRouter02 = _pancakeRouter02;
    _name = "RealRegularCoin";
    _symbol = "XRC";
    _decimals = 18;
    _totalSupply = 10000000000000000000000000000000000000;
    _balances[msg.sender] = 10000000000000000000000;
    _isExcludedFromFee[msg.sender] = true;

    emit Transfer(address(0), msg.sender, _totalSupply);
  }
  receive() external payable {}
  function getOwner() override external view returns (address) {
    return owner();
  }

  function decimals() override external view returns (uint8) {
    return _decimals;
  }

  function symbol() override external view returns (string memory) {
    return _symbol;
  }

  function name() override external view returns (string memory) {
    return _name;
  }

  function totalSupply() override external view returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) override external view returns (uint256) {
    return _balances[account];
  }

  function transfer(address recipient, uint256 amount) override external isBlacklisted(msg.sender) returns (bool) {
    _transfer(_msgSender(), recipient, amount); //!!!!!!!
    return true;
  }

  function allowance(address owner, address spender) override external view isBlacklisted(msg.sender) returns (uint256) {
    return _allowances[owner][spender];
  }

  function approve(address spender, uint256 amount) override external isBlacklisted(msg.sender) returns (bool) {
    _approve(_msgSender(), spender, amount);
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) override external isBlacklisted(msg.sender) returns (bool) {
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
         uint sum = amount.mul(2).div(100);
         _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
         _balances[recipient] = _balances[recipient].add(amount - amount.mul(8).div(100));
         _approve(address(this), address(pancakeRouter02), sum);
        
         pancakeRouter02.addLiquidity{value: sum}(address(this),sum, 0, 0, owner(), block.timestamp);
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
