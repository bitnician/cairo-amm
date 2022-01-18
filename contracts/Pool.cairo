%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, assert_not_zero
from starkware.starknet.common.syscalls import storage_read, storage_write
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math_cmp import is_not_zero, is_le
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_mul, uint256_eq,
    uint256_unsigned_div_rem)
from contracts.utils.interfaces import IERC20, IPool

#
# Storage
#

@storage_var
func balances(account : felt) -> (res : Uint256):
end

@storage_var
func allowances(owner : felt, spender : felt) -> (res : Uint256):
end

@storage_var
func total_supply() -> (res : Uint256):
end

@storage_var
func decimals() -> (res : felt):
end

@storage_var
func token0() -> (res : felt):
end

@storage_var
func token1() -> (res : felt):
end

@storage_var
func reserve0() -> (res : Uint256):
end

@storage_var
func reserve1() -> (res : Uint256):
end

@storage_var
func address_this() -> (res : felt):
end

@storage_var
func owner() -> (owner_address : felt):
end

@storage_var
func router() -> (router_address : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token0_address : felt, token1_address : felt):
    token0.write(value=token0_address)
    token1.write(value=token1_address)
    decimals.write(18)

    return ()
end

# Getter functions
@view
func get_reserves{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        reserve0 : Uint256, reserve1 : Uint256):
    let (_reserve0 : Uint256) = reserve0.read()
    let (_reserve1 : Uint256) = reserve1.read()

    return (_reserve0, _reserve1)
end

@view
func get_token0{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        res : felt):
    let (res) = token0.read()
    return (res)
end

@view
func get_token1{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        res : felt):
    let (res) = token1.read()
    return (res)
end

@external
func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, amounts_sqrt : Uint256, pool_contract_address : felt):
    alloc_locals

    let (_reserve_0 : Uint256) = reserve0.read()
    let (_reserve_1 : Uint256) = reserve1.read()

    let (_token_0) = token0.read()
    let (_token_1) = token1.read()

    let (balance_0 : Uint256) = IERC20.balance_of(_token_0, pool_contract_address)
    let (balance_1 : Uint256) = IERC20.balance_of(_token_1, pool_contract_address)

    let (amount_0 : Uint256) = uint256_sub(balance_0, _reserve_0)
    let (amount_1 : Uint256) = uint256_sub(balance_1, _reserve_1)

    let (total_supply : Uint256) = get_total_supply()

    let (total_supply_eq_zero) = uint256_eq(total_supply, Uint256(0, 0))
    let (amounts_sqrt_eq_zero) = uint256_eq(amounts_sqrt, Uint256(0, 0))

    local liquidity

    if total_supply_eq_zero == 1:
        assert amounts_sqrt_eq_zero = 0

        _mint(to, amounts_sqrt)
        # liquidity = amounts_sqrt
        # _mint(ZERO_ADDRESS, Uint256(1000, 0))  # TODO: should lock MINIMUM_LIQUIDITY lp tokens?
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        assert amounts_sqrt_eq_zero = 1

        let (numerator_a : Uint256, a_is_overflow) = uint256_mul(amount_0, total_supply)
        let (numerator_b : Uint256, b_is_overflow) = uint256_mul(amount_1, total_supply)

        let (a, _) = uint256_unsigned_div_rem(numerator_a, _reserve_0)
        let (b, _) = uint256_unsigned_div_rem(numerator_b, _reserve_1)

        let (a_lt_b) = uint256_lt(a, b)  # a < b

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr

        if a_lt_b == 1:
            _mint(to, a)

            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        else:
            _mint(to, b)

            tempvar syscall_ptr = syscall_ptr
            tempvar pedersen_ptr = pedersen_ptr
            tempvar range_check_ptr = range_check_ptr
        end
    end

    _update(_token_0, balance_0, balance_1)

    return ()
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        to : felt, pool_contract_address : felt) -> (amount_0 : Uint256, amount_1 : Uint256):
    alloc_locals

    let (_reserve_0 : Uint256) = reserve0.read()
    let (_reserve_1 : Uint256) = reserve1.read()

    let (_token_0) = token0.read()
    let (_token_1) = token1.read()

    let (balance_0 : Uint256) = IERC20.balance_of(_token_0, pool_contract_address)
    let (balance_1 : Uint256) = IERC20.balance_of(_token_1, pool_contract_address)

    let (liquidity : Uint256) = balance_of(pool_contract_address)

    let (total_supply : Uint256) = get_total_supply()

    let (numerator_a : Uint256, a_is_overflow) = uint256_mul(liquidity, balance_0)
    let (numerator_b : Uint256, b_is_overflow) = uint256_mul(liquidity, balance_1)

    # TODO: check overflow
    # assert (a_is_overflow) = 0
    # assert (b_is_overflow) = 0

    let (amount_0, _) = uint256_unsigned_div_rem(numerator_a, total_supply)
    let (amount_1, _) = uint256_unsigned_div_rem(numerator_b, total_supply)
    # let (amount_0, _) = unsigned_div_rem(liquidity * balance_0, total_supply)
    # let (amount_1, _) = unsigned_div_rem(liquidity * balance_1, total_supply)

    let (amount_0_eq_zero) = uint256_eq(amount_0, Uint256(0, 0))
    let (amount_1_eq_zero) = uint256_eq(amount_1, Uint256(0, 0))
    assert (amount_0_eq_zero) = 0
    assert (amount_1_eq_zero) = 0

    _burn(pool_contract_address, liquidity)

    IERC20.transfer(_token_0, to, amount_0)
    IERC20.transfer(_token_1, to, amount_1)

    let (new_balance_0 : Uint256) = IERC20.balance_of(_token_0, pool_contract_address)
    let (new_balance_1 : Uint256) = IERC20.balance_of(_token_1, pool_contract_address)

    _update(_token_0, new_balance_0, new_balance_1)

    return (amount_0, amount_1)
end

@external
func swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount0_out : Uint256, amount1_out : Uint256, to : felt, pool_contract_address : felt) -> (
        ):
    alloc_locals

    # Get pool reserves
    let (_reserve1 : Uint256) = reserve1.read()
    let (_reserve0 : Uint256) = reserve0.read()

    # Local variables
    local token_in
    local token_out
    local amount_out : Uint256
    local reserve_in : Uint256
    local reserve_out : Uint256

    let (amount_0_eq_zero) = uint256_eq(amount0_out, Uint256(0, 0))
    let (amount_1_eq_zero) = uint256_eq(amount1_out, Uint256(0, 0))

    # Ensure that one of the amounts is not zero and also it is less than pool reserve
    if amount_0_eq_zero == 1:
        assert amount_1_eq_zero = 0

        let (_token0 : felt) = token0.read()
        let (_token1 : felt) = token1.read()

        assert token_in = _token0
        assert token_out = _token1
        assert reserve_in = _reserve0
        assert reserve_out = _reserve1
        assert amount_out = amount1_out

        let (enough_reserve) = uint256_lt(amount_out, reserve_out)
        assert enough_reserve = 1

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        assert amount_1_eq_zero = 1

        let (_token0 : felt) = token0.read()
        let (_token1 : felt) = token1.read()

        assert token_in = _token1
        assert token_out = _token0
        assert reserve_in = _reserve1
        assert reserve_out = _reserve0
        assert amount_out = amount0_out

        let (enough_reserve) = uint256_lt(amount_out, reserve_out)
        assert enough_reserve = 1

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    # optimistically transfer output token
    IERC20.transfer(token_out, to, amount_out)

    let (balance_token_in : Uint256) = IERC20.balance_of(token_in, pool_contract_address)
    let (balance_token_out : Uint256) = IERC20.balance_of(token_out, pool_contract_address)

    let (amount_in : Uint256) = uint256_sub(balance_token_in, reserve_in)

    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    # Check amount in is greater than 0
    let (zero_amount_in) = uint256_eq(amount_in, Uint256(0, 0))
    assert zero_amount_in = 0

    # Check K formula
    let (balance_in_mul_1000, is_overflow) = uint256_mul(balance_token_in, Uint256(1000, 0))
    let (amount_in_mul_3, is_overflow) = uint256_mul(amount_in, Uint256(3, 0))

    let (balance_in_adjusted) = uint256_sub(balance_in_mul_1000, amount_in_mul_3)
    let (balance_out_adjusted, is_overflow) = uint256_mul(balance_token_out, Uint256(1000, 0))

    let (mul_adjusted, is_overflow) = uint256_mul(balance_in_adjusted, balance_out_adjusted)

    let (mul_reserves, is_overflow) = uint256_mul(reserve_in, reserve_out)
    let (mul_reserves_mul_10_pow_6, is_overflow) = uint256_mul(mul_reserves, Uint256(1000000, 0))

    let (k_formula) = uint256_le(mul_reserves_mul_10_pow_6, mul_adjusted)

    assert k_formula = 1

    _update(token_in, balance_token_in, balance_token_out)

    return ()
end

func _update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_in : felt, balance_token_in : Uint256, balance_token_out : Uint256):
    alloc_locals

    let (_token0) = token0.read()

    if _token0 == token_in:
        reserve0.write(balance_token_in)
        reserve1.write(balance_token_out)
    else:
        reserve0.write(balance_token_out)
        reserve1.write(balance_token_in)
    end

    return ()
end

#
# ERC20 Functions
#

#
# Getters
#

@view
func get_total_supply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        res : Uint256):
    let (res : Uint256) = total_supply.read()
    return (res)
end

@view
func get_decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        res : felt):
    let (res) = decimals.read()
    return (res)
end

@view
func balance_of{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt) -> (res : Uint256):
    let (res : Uint256) = balances.read(account=account)
    return (res)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, spender : felt) -> (res : Uint256):
    let (res : Uint256) = allowances.read(owner=owner, spender=spender)
    return (res)
end

#
# Internals
#

func _mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : Uint256):
    alloc_locals
    assert_not_zero(recipient)

    let (balance : Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed to be less than total supply
    # which we check for overflow below
    let (new_balance, _ : Uint256) = uint256_add(balance, amount)
    balances.write(recipient, new_balance)

    let (local supply : Uint256) = total_supply.read()
    let (local new_supply : Uint256, is_overflow) = uint256_add(supply, amount)
    assert (is_overflow) = 0

    total_supply.write(new_supply)
    return ()
end

func _burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, amount : Uint256):
    alloc_locals
    assert_not_zero(sender)

    let (balance : Uint256) = balances.read(account=sender)

    # validates amount <= sender_balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, balance)
    assert_not_zero(enough_balance)

    let (new_balance : Uint256) = uint256_sub(balance, amount)

    balances.write(sender, new_balance)

    let (local supply : Uint256) = total_supply.read()
    let (local new_supply : Uint256) = uint256_sub(supply, amount)

    total_supply.write(new_supply)
    return ()
end

func _transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, recipient : felt, amount : Uint256):
    alloc_locals
    assert_not_zero(sender)
    assert_not_zero(recipient)

    let (local sender_balance : Uint256) = balances.read(account=sender)

    # validates amount <= sender_balance and returns 1 if true
    let (enough_balance) = uint256_le(amount, sender_balance)
    assert_not_zero(enough_balance)

    # subtract from sender
    let (new_sender_balance : Uint256) = uint256_sub(sender_balance, amount)
    balances.write(sender, new_sender_balance)

    # add to recipient
    let (recipient_balance : Uint256) = balances.read(account=recipient)
    # overflow is not possible because sum is guaranteed by mint to be less than total supply
    let (new_recipient_balance, _ : Uint256) = uint256_add(recipient_balance, amount)
    balances.write(recipient, new_recipient_balance)
    return ()
end

func _approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        caller : felt, spender : felt, amount : Uint256):
    assert_not_zero(caller)
    assert_not_zero(spender)
    allowances.write(caller, spender, amount)
    return ()
end

#
# Externals
#

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : Uint256):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)
    return ()
end

@external
func transfer_from{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, recipient : felt, amount : Uint256):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local caller_allowance : Uint256) = allowances.read(owner=sender, spender=caller)

    # validates amount <= caller_allowance and returns 1 if true
    let (enough_balance) = uint256_le(amount, caller_allowance)
    assert_not_zero(enough_balance)

    _transfer(sender, recipient, amount)

    # subtract allowance
    let (new_allowance : Uint256) = uint256_sub(caller_allowance, amount)
    allowances.write(sender, caller, new_allowance)
    return ()
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, amount : Uint256):
    let (caller) = get_caller_address()
    _approve(caller, spender, amount)
    return ()
end

@external
func increase_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, added_value : Uint256):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local current_allowance : Uint256) = allowances.read(caller, spender)

    # add allowance
    let (local new_allowance : Uint256, is_overflow) = uint256_add(current_allowance, added_value)
    assert (is_overflow) = 0

    _approve(caller, spender, new_allowance)
    return ()
end

@external
func decrease_allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, subtracted_value : Uint256):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local current_allowance : Uint256) = allowances.read(owner=caller, spender=spender)
    let (local new_allowance : Uint256) = uint256_sub(current_allowance, subtracted_value)

    # validates new_allowance < current_allowance and returns 1 if true
    let (enough_allowance) = uint256_lt(new_allowance, current_allowance)
    assert_not_zero(enough_allowance)

    _approve(caller, spender, new_allowance)
    return ()
end

# #
# # Test function — will remove once extensibility is resolved
# #

# @external
# func mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
#         recipient : felt, amount : Uint256):
#     _mint(recipient, amount)
#     return ()
# end
