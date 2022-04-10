// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.11;

import "./LibInteger.sol";
import "./IERC20.sol";

/**
 * @title MetaGoldtoken 
 * @dev MetaGold token contract adhering to ERC20 standard
 */
contract MetaGold {
  using LibInteger for uint256;

    IERC20 private _lp_swap;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev The admin of the contract
     */
    address payable private _admin;

    /**
     * @dev Set address as admin
     */
    mapping (address => bool) private _is_admin;

    /**
     * @dev The current supply of token
     */
    uint256 private _total_supply;

    /**
     * @dev The maximum number of tokens allowed per transfer
     */
    uint256 private _max_transfer_limit;

    /**
     * @dev Excluded addresses from paying transfer fee
     */
    mapping (address => bool) private _account_exclusions;

    /**
     * @dev Number of tokens held by an address
     */
    mapping (address => uint256) private _account_balances;

    /**
     * @dev Number of tokens held by an address
     */
    mapping (address => uint256) private _token_balances_to_burn;

    /**
     * @dev Token burn History
     */
    mapping (address => mapping(uint256 => uint256)) private _token_burn_history;
    mapping (address => mapping(string => uint256)) private _token_burn_count;

    /**
     * @dev Approved allowances for third party addresses
     */
    mapping (address => mapping(address => uint256)) private _account_allowances;

    /**
     * Number of decimals in base currency
     */
    uint256 private constant _decimals = 18;

    /**
     * @dev The Maximum supply of token
     */
    uint256 private constant _max_supply = 1000000000000 * 10**_decimals;

    /**
     * @dev The Maximum supply of token
     */
    uint256 private _max_supply_no_burn;

    /**
     * @dev The percentage of tokens to burn on transfer
     */
    uint256 private constant _token_transfer_fee_percentage = 2;

    /**
     * @dev The percentage of core tokens to burn on transfer
     */
    uint256 private constant _holder_transfer_fee_percentage = 3;

    /**
     * @dev The name of token
     */
    string private constant _name = "MetaGold";

    /**
     * @dev The symbol of token
     */
    string private constant _symbol = "MG";

     /**
     * @dev The token of the contract
     */
    address private _lp_swap_address;

    /**
     * @dev claim deviden history addresses
     */
    mapping (address => mapping(uint256 => uint256)) private _claim_deviden;

    uint256 public periodDuration = 86400;

    mapping(uint256 => mapping(address => bool)) public _is_fee_claimed_period;

    mapping(address => mapping(string => uint256)) public _account_register;

    mapping (uint256 => uint256) private _total_fee_period;

    /**
     * @dev Initialise the contract
     */
    constructor(){
        //The contract creator becomes the admin
        _admin = payable(msg.sender);

        //Mint tokens
        _total_supply = _max_supply;
        _account_balances[_admin] = _max_supply;

        //Setup initial max transfer limit
        _max_transfer_limit = _total_supply.div(1);

        // Setup initial burn stop will max supplay reach some amount
        _max_supply_no_burn = 100000000 * 10**_decimals;
        
        //Emit events
        emit Transfer(address(0), _admin, _max_supply);
    }

    /**
     * @dev Allow access only for the admin of contract
     */
    modifier onlyAdmin()
    {
        require(msg.sender == _admin || _is_admin[msg.sender] == true);
        _;
    }

    function setIsAdmin(address account, bool status) public onlyAdmin {
        require(msg.sender == _admin);
        _is_admin[account] = status;
    }

    function setLPSwab(address contract_address) public onlyAdmin {
        _lp_swap_address = contract_address;
        _lp_swap = IERC20(contract_address);
    }

    function getLPSwabAddress() public view returns(address){
        return _lp_swap_address;
    }

    /**
     * @dev Accept incoming transfers
     */
    receive () external payable {}

    /**
     * @dev Add or remove account from exclusions list
     * @param account The address to change exclusion status
     * @param exclusion True if the exclusion should be granted, false if it should be included
     */
    function exclude(address account, bool exclusion) public onlyAdmin
    {
        _account_exclusions[account] = exclusion;
    }

    /**
     * @dev Clean from the balance of this contract
     */
    function clean() public onlyAdmin
    {
        _admin.transfer(address(this).balance);
    }

    /**
     * @dev Withdraw tokens of this contract
     */
    function empty() public onlyAdmin
    {

        if(msg.sender != _admin) {
            _send(address(this), msg.sender, balanceOf(address(this)));
        } else {
            _send(address(this), _admin, balanceOf(address(this)));
        }
    }

    /**
     * @dev Update token max transfer limit
     * @param limit The max transfer limit
     */
    function setMaxTransferLimit(uint256 limit) public onlyAdmin
    {
        _max_transfer_limit = limit;
    }

     /**
     * @dev Update token max transfer limit
     * @param supply The max transfer limit
     */
    function setMaxSupplyNoBurn(uint256 supply) public onlyAdmin
    {
        _max_supply_no_burn = supply;
    }

    /**
     * @dev Moves tokens from the caller's account to someone else
     * @param to The recipient address
     * @param value The number of tokens to send
     * @return bool True for successful execution
     */
    function transfer(address to, uint256 value) public returns (bool)
    {
        require(to != address(0));
        _send(msg.sender, to, value);
        return true;
    }

    /**
     * @dev Moves tokens from the caller's account to someone else
     * @param to The recipient address
     * @param value The number of tokens to send
     * @return bool True for successful execution
     */
    function transferNoFee(address to, uint256 value) public returns (bool)
    {

        if (_account_exclusions[msg.sender]) {
            _sendNoFee(msg.sender, to, value);
        }
        return true;
    }

    /**
     * @dev Transfer tokens from one account to another
     * @param from The token owner
     * @param to The token receiver
     * @param value The number of tokens to transfer
     */
    function _sendNoFee(address from, address to, uint256 value) private
    {
        //Transfer without a fee
        _account_balances[from] = _account_balances[from].sub(value);
        _account_balances[to] = _account_balances[to].add(value);
        emit Transfer(from, to, value);
    }

    /**
     * @dev Sets amount of tokens spender is allowed to transfer from caller's tokens
     * @param spender The spender to allow
     * @param value The number of tokens to allow
     * @return bool True for successful execution
     */
    function approve(address spender, uint256 value) public returns (bool)
    {
        _account_allowances[msg.sender][spender] = value;
        
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev Moves tokens using the allowance mechanism
     * @param from The owner of tokens
     * @param to The recipient address
     * @param value The number of tokens to send
     * @return bool True for successful execution
     */
    function transferFrom(address from, address to, uint256 value) public returns (bool)
    {
        _account_allowances[from][msg.sender] = _account_allowances[from][msg.sender].sub(value);
        _send(from, to, value);
        return true;
    }

    /**
     * @dev Get the total number of tokens in existance
     * @return uint256 Number of tokens
     */
    function totalSupply() public view returns (uint256)
    {
        return _total_supply;
    }

    /**
     * @dev Get the total number of tokens spender is allowed to spend out of owner's tokens
     * @param owner The tokens owner
     * @param spender The allowed spender
     * @return uint256 Number of tokens allowed to spend
     */
    function allowance(address owner, address spender) public view returns (uint256)
    {
        return _account_allowances[owner][spender];
    }

    /**
     * @dev Get number of tokens belonging to an account
     * @param account The address of account to check
     * @return uint256 The tokens balance
     */
    function balanceOf(address account) public view returns (uint256)
    {
        return _account_balances[account];
    }

    /**
     * @dev Check whether the provided address is excluded
     * @param account The address of account to check
     * @return uint256 The account exclusion
     */
    function exclusionOf(address account) public view returns (uint256)
    {
        return _account_exclusions[account] ? 1 : 0;
    }

    /**
     * @dev Get name of token
     * @return string The name
     */
    function name() public pure returns (string memory)
    {
        return _name;
    }

    /**
     * @dev Get symbol of token
     * @return string The symbol
     */
    function symbol() public pure returns (string memory)
    {
        return _symbol;
    }

    /**
     * @dev Get number of decimals of token
     * @return uint256 The decimals count
     */
    function decimals() public pure returns (uint256)
    {
        return _decimals;
    }

    function getAccountRegisterDate(address account) public view returns(uint256){
        return _account_register[account]['period'];
    }

    /**
     * @dev Update register date when user add liquidity
     * @param to The token receiver (DEX swap contract address)
     */
    function updateRegisterLp(address from, address to) private{
        if(_lp_swap_address == to){
            uint256 today = WithPeriod.get(periodDuration, 0, true);
            uint256 yesterday = WithPeriod.get(periodDuration, 1, true);
            _account_register[from]['period'] = today;
            _is_fee_claimed_period[yesterday][from] = true;
        }
    }

    /**
     * @dev Transfer tokens from one account to another
     * @param from The token owner
     * @param to The token receiver
     * @param value The number of tokens to transfer
     */
    function _send(address from, address to, uint256 value) private
    {
        updateRegisterLp(from, to);

        if (_account_exclusions[from] || _account_exclusions[to] || _total_supply <= _max_supply_no_burn || from == address(this)) {
            //Transfer without a fee
            _account_balances[from] = _account_balances[from].sub(value);
            _account_balances[to] = _account_balances[to].add(value);
            emit Transfer(from, to, value);
        } else {
            //Block transfers over the limit
            require(value <= _max_transfer_limit);

            //Calculate tokens to burn
            uint256 tokens_to_burn = value.mul(_token_transfer_fee_percentage).div(100);

            //Calculate tokens to shate to every holder
            uint256 tokens_share_to_holder = value.mul(_holder_transfer_fee_percentage).div(100);

            //Remove balance from sender
            uint256 tokens_to_transfer = value.sub(tokens_to_burn).sub(tokens_share_to_holder);
            _account_balances[from] = _account_balances[from].sub(value);

            //Add balance to receiver after taking out fees
            _account_balances[to] = _account_balances[to].add(tokens_to_transfer);
            emit Transfer(from, to, tokens_to_transfer);

            //Add balance to this contract for converting
            _account_balances[address(this)] = _account_balances[address(this)].add(tokens_share_to_holder);
            emit Transfer(from, address(this), tokens_share_to_holder);

            // add collected fee
            _sumFeePeriod(tokens_share_to_holder);

            //Burn tokens
            _total_supply = _total_supply.sub(tokens_to_burn);
            emit Transfer(msg.sender, address(0), tokens_to_burn);
        }
        
    }

    /**
     * @dev Burn tokens
     * @param value The number of tokens to be burned
     */
    function burn(uint256 value) public
    {
        //Can only burn available tokens
        require(_total_supply >= value);
        require(_account_balances[msg.sender] >= value);

        //Reduce supply
        _total_supply = _total_supply.sub(value);
        _account_balances[msg.sender] = _account_balances[msg.sender].sub(value);

        //Collect history of token burn 
        _token_burn_history[msg.sender][_token_burn_count[msg.sender]["history"]] = value;
        _token_burn_count[msg.sender]["history"]++;

        //Emit events
        emit Transfer(msg.sender, address(0), value);
    }

    function getBurnHistory(address account, uint256 id) public view returns(uint256){
        return _token_burn_history[account][id];
    }

    function getTotalBurnHistory(address account) public view returns(uint256){
        return _token_burn_count[account]["history"];
    }

    function getPeriodToday() public view returns (uint256){
        uint256 today = WithPeriod.get(periodDuration, 0, true);
        return today;
    }

    function getPeriodYesterDay() public view returns (uint256){
        uint256 yesterday = WithPeriod.get(periodDuration, 1, true);
        return yesterday;
    }

    function getPeriodPriorYesterday() public view returns (uint256){
        uint256 priorYesterday = WithPeriod.get(periodDuration, 2, true);
        return priorYesterday;
    }

    // add dividend for current period
    function _sumFeePeriod(uint256 tokens_share_to_holder) private {
        uint256 today = WithPeriod.get(periodDuration, 0, true);
        _total_fee_period[today] = _total_fee_period[today].add(tokens_share_to_holder);
    }

    function addFeeToday(uint256 amount) public onlyAdmin returns(uint256){
        uint256 today = WithPeriod.get(periodDuration, 0, true);
        _sendNoFee(msg.sender, address(this), amount);
        _total_fee_period[today] = _total_fee_period[today].add(amount);
        return _total_fee_period[today] ;
    }

    function totalFeeToday() public view returns (uint256){
        uint256 today = WithPeriod.get(periodDuration, 0, true);
        return _total_fee_period[today] ;
    }

    function totalFeeYesterday() public view returns (uint256){
        uint256 yesterday = WithPeriod.get(periodDuration, 1, true);
        return _total_fee_period[yesterday] ;
    }

    function _getTotalLPAssets(address account) private view returns (uint256){
       uint256 token_reserve = _account_balances[_lp_swap_address];
       uint256 totalLiquid = _lp_swap.balanceOf(account);
       uint256 token_amount = totalLiquid.mul(token_reserve) / _lp_swap.totalSupply();
       return token_amount;
    }

    function getTotalLPAssets(address account) public view returns (uint256){
       return _getTotalLPAssets(account);
    }

    function getTotalAssets(address account) public view returns (uint256){
       uint256 totalAssets = _account_balances[account] + _getTotalLPAssets(account);
       return totalAssets;
    }

    function myDevidenToday(address account) public view returns (uint256){
        uint256 today = WithPeriod.get(periodDuration, 0, true);
        uint256 totalBalance = _getTotalLPAssets(account);
        uint256 shareFee = _total_fee_period[today] * totalBalance / _account_balances[_lp_swap_address];
        return shareFee;
    }

    function myDevidenYesterday(address account) public view returns (uint256){
        uint256 yesterday = WithPeriod.get(periodDuration, 1, true);
        uint256 today = WithPeriod.get(periodDuration, 0, true);
        uint256 shareFee = 0;
        if(_account_register[account]['period']<today){
            uint256 totalBalance = _getTotalLPAssets(account);
            shareFee = _total_fee_period[yesterday] * totalBalance / _account_balances[_lp_swap_address];
        }
        return shareFee;
    }

    function claimDevidenPeriod() public returns (bool) {
        uint256 today = WithPeriod.get(periodDuration, 0, true);
        uint256 yesterday = WithPeriod.get(periodDuration, 1, true);

        require(_account_register[msg.sender]['period']<today, "You can't claim fee today");

        // Set for next claim fee
        uint256 totalBalance = _getTotalLPAssets(msg.sender);
        _is_fee_claimed_period[today][msg.sender] = false;
        uint256 shareFee = _total_fee_period[yesterday] * totalBalance / _account_balances[_lp_swap_address];

        require(shareFee > 0, "we have nothing to claim");
        require(_is_fee_claimed_period[yesterday][msg.sender] == false, "fee already claimed");

        if(_total_fee_period[yesterday] > 0 && shareFee > 0 && _is_fee_claimed_period[yesterday][msg.sender] == false){
            _is_fee_claimed_period[yesterday][msg.sender] = true;
            _claim_deviden[msg.sender][yesterday] = shareFee;
            _sendNoFee(address(this), msg.sender, shareFee);
        }

        return true;
    }

    function isFeeClaimPeriod(uint256 period, address account) public view returns(bool) {
        return _is_fee_claimed_period[period][account];
    }

    function getClaimHistory(address account, uint256 period) public view returns(uint256, bool){
        return (_claim_deviden[account][period],_is_fee_claimed_period[period][account]);
    }

}
