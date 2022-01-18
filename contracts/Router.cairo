%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, assert_not_zero
from starkware.cairo.common.math_cmp import is_nn_le, is_not_zero
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.syscalls import get_caller_address, get_tx_signature
from starkware.cairo.common.hash_state import (
    hash_init, hash_finalize, hash_update, hash_update_single)
from starkware.cairo.common.registers import get_fp_and_pc
from contracts.utils.interfaces import IERC20, IPool
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_mul, uint256_eq,
    uint256_unsigned_div_rem)

@storage_var
func owner() -> (owner_address : felt):
end

@storage_var
func whitlisted_pool(pool_contract_address : felt) -> (res : felt):
end

@storage_var
func pool_address(token_0 : felt, token_1 : felt) -> (pool_contract_address : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner_address : felt):
    owner.write(value=owner_address)
    return ()
end

# @notice It checks if the caller is the owner of the contract.
# @returns the owner address if the caller is the owner, otherwise it throws an error.
func only_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (_owner):
    alloc_locals
    let (local caller) = get_caller_address()
    let (_owner) = owner.read()
    assert caller = _owner
    return (_owner)
end

# @notice It accepts a pool contract address as argument and check if the given address is whitelisted.
# @param pool_contract_address the address of the pool contract.
# @dev It throws an error if the given address is not whitelisted.
@view
func verify_pool_is_whitelisted{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_contract_address : felt) -> ():
    let (res) = whitlisted_pool.read(pool_contract_address)
    assert_not_zero(res)

    return ()
end

# @notice It accepts the token0 and token1 addresses as arguments and returns the pool contract address.
# @param token0 : the token0 address
# @param token1 : the token1 address
# @returns the pool contract address
# @dev It return 0 if the pool contract address is not found.
@view
func get_pool_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_a_address : felt, token_b_address : felt) -> (pool_contract_address : felt):
    let (pool_contract_address : felt) = pool_address.read(token_a_address, token_b_address)

    return (pool_contract_address)
end

# @notice Given some asset amount and reserves, returns an amount of the other asset representing
# equivalent value.
# @param amount_a : the amount of asset A
# @param reserve_a : the reserve of asset A
# @param reserve_b : the reserve of asset B
# @returns amount_b : the amount of asset B
@view
func quote{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_a : Uint256, reserve_a : Uint256, reserve_b : Uint256) -> (amount_b : Uint256):
    alloc_locals
    let (amount_a_is_zero) = uint256_eq(amount_a, Uint256(0, 0))
    let (reserve_a_is_zero) = uint256_eq(reserve_a, Uint256(0, 0))
    let (reserve_b_is_zero) = uint256_eq(reserve_b, Uint256(0, 0))

    assert amount_a_is_zero = 0
    assert reserve_a_is_zero = 0
    assert reserve_b_is_zero = 0

    let (amount_a_mul_reserve_b, is_overflow) = uint256_mul(amount_a, reserve_b)

    let (amount_b, _) = uint256_unsigned_div_rem(amount_a_mul_reserve_b, reserve_a)

    return (amount_b)
end

# @notice It whitelists a pool contract address.
# @param pool_contract_address : the address of the pool contract.
# @dev It throws an error if the given address is already whitelisted OR the caller is not Owner.
@external
func whitelist_pool{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_contract_address) -> ():
    alloc_locals
    only_owner()

    let (token0) = IPool.get_token0(pool_contract_address)
    let (token1) = IPool.get_token1(pool_contract_address)

    assert_not_zero(token0)
    assert_not_zero(token1)

    # pool is not whitelisted yet
    let (res) = whitlisted_pool.read(pool_contract_address)
    assert res = 0

    whitlisted_pool.write(pool_contract_address, 1)

    pool_address.write(token0, token1, pool_contract_address)
    pool_address.write(token1, token0, pool_contract_address)

    return ()
end

# @notice It add the first amounts of liquidity to the pool.
# @param sender : the address that receives lp tokens
# @param token_a_address : the address of the token0
# @param token_b_address : the address of the token1
# @param amount_a : the amount of token0
# @param amount_b : the amount of token1
# @param amounts_sqrt : square_root(amount_a_desired * amount_b_desired)
# @dev It throws an error if the caller is not the owner OR the pool is not whitelisted
# OR the amount is not valid OR the pool has already some amounts of liquidity.
@external
func init_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, token_a_address : felt, token_b_address : felt, amount_a_desired : Uint256,
        amount_b_desired : Uint256, amounts_sqrt : Uint256) -> ():
    alloc_locals
    let (_owner) = only_owner()

    let (pool_contract_address) = get_pool_address(token_a_address, token_b_address)

    verify_pool_is_whitelisted(pool_contract_address)

    let (local token_a_reserve : Uint256) = get_pool_reserve(pool_contract_address, token_a_address)

    let (local token_b_reserve : Uint256) = get_pool_reserve(pool_contract_address, token_b_address)

    # Check to see if the pool balance is zero.
    let (reserve_a_zero) = uint256_eq(token_a_reserve, Uint256(0, 0))
    let (reserve_b_zero) = uint256_eq(token_b_reserve, Uint256(0, 0))

    assert reserve_a_zero = 1
    assert reserve_b_zero = 1

    IERC20.transferFrom(token_a_address, sender, pool_contract_address, amount_a_desired)
    IERC20.transferFrom(token_b_address, sender, pool_contract_address, amount_b_desired)

    IPool.mint(pool_contract_address, _owner, amounts_sqrt, pool_contract_address)
    return ()
end

# @notice It adds liquidity to the pool. can be called by anyone
# @param token_a_address : the address of the token0
# @param token_b_address : the address of the token1
# @param amount_a_desired : The amount of tokenA to add as liquidity if
# the B/A price is <= amountBDesired/amountADesired (A depreciates).
# @param amount_b_desired : The amount of tokenB to add as liquidity if
# the A/B price is <= amountADesired/amountBDesired (B depreciates).
# @param amount_a_min : Bounds the extent to which the B/A price can go up before
# the transaction reverts. Must be <= amountADesired.
# @param amount_b_min : Bounds the extent to which the A/B price can go up before
# the transaction reverts. Must be <= amountBDesired.
@external
func add_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_a_address : felt, token_b_address : felt, amount_a_desired : Uint256,
        amount_b_desired : Uint256, amount_a_min : Uint256, amount_b_min : Uint256) -> ():
    alloc_locals

    let (local caller) = get_caller_address()

    let (pool_contract_address) = get_pool_address(token_a_address, token_b_address)

    verify_pool_is_whitelisted(pool_contract_address)

    let (local token_a_reserve : Uint256) = get_pool_reserve(pool_contract_address, token_a_address)
    let (local token_b_reserve : Uint256) = get_pool_reserve(pool_contract_address, token_b_address)

    # Check to see if the pool balance is not zero.
    let (reserve_a_zero) = uint256_eq(token_a_reserve, Uint256(0, 0))
    let (reserve_b_zero) = uint256_eq(token_b_reserve, Uint256(0, 0))

    assert reserve_a_zero = 0
    assert reserve_b_zero = 0

    local amount_a : Uint256
    local amount_b : Uint256

    let (amount_b_optimal : Uint256) = quote(amount_a_desired, token_a_reserve, token_b_reserve)
    let (amount_a_optimal : Uint256) = quote(amount_b_desired, token_b_reserve, token_a_reserve)

    let (validate_b_optimal) = uint256_le(amount_b_optimal, amount_b_desired)

    if validate_b_optimal == 1:
        let (enough_b_optimal) = uint256_le(amount_b_min, amount_b_optimal)
        assert enough_b_optimal = 1

        assert amount_a = amount_a_desired
        assert amount_b = amount_b_optimal

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        let (validate_a_optimal) = uint256_le(amount_a_optimal, amount_a_desired)
        assert validate_a_optimal = 1

        let (enough_a_optimal) = uint256_le(amount_a_min, amount_a_optimal)
        assert enough_a_optimal = 1

        assert amount_a = amount_a_optimal
        assert amount_b = amount_b_desired

        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end

    IERC20.transferFrom(token_a_address, caller, pool_contract_address, amount_a)
    IERC20.transferFrom(token_b_address, caller, pool_contract_address, amount_b)

    IPool.mint(pool_contract_address, caller, Uint256(0, 0), pool_contract_address)

    return ()
end

# @notice It removes liquidity from the pool. can be called by anyone
# @param token_a_address : the address of the token0
# @param token_b_address : the address of the token1
# @param liquidity_amount : The amount of liquidity tokens to remove.
# @param amount_a_min : The minimum amount of tokenA that must be received for
# the transaction not to revert.
# @param amount_b_min : The minimum amount of tokenB that must be received for
# the transaction not to revert.
# @param to : Recipient of the underlying assets.
@external
func remove_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_a_address : felt, token_b_address : felt, liquidity_amount : Uint256,
        amount_a_min : Uint256, amount_b_min : Uint256, to : felt) -> ():
    alloc_locals

    let (local caller) = get_caller_address()

    let (pool_contract_address) = get_pool_address(token_a_address, token_b_address)

    verify_pool_is_whitelisted(pool_contract_address)

    IPool.transferFrom(pool_contract_address, caller, pool_contract_address, liquidity_amount)
    let (amount_0 : Uint256, amount_1 : Uint256) = IPool.burn(
        pool_contract_address, to, pool_contract_address)

    local amount_a : Uint256
    local amount_b : Uint256

    let (token_0) = IPool.get_token0(pool_contract_address)

    if token_0 == token_a_address:
        assert amount_a = amount_0
        assert amount_b = amount_1
    else:
        assert amount_a = amount_1
        assert amount_b = amount_0
    end

    let (enough_amount_a) = uint256_le(amount_a_min, amount_a)
    let (enough_amount_b) = uint256_le(amount_b_min, amount_b)

    assert enough_amount_a = 1
    assert enough_amount_b = 1

    return ()
end

# @notice Getting the pool reserve of token.
# @param pool_contract_address : address of the pool contract
# @param token_address : address of the token
# @return The reserve of the other token of pool.
func get_pool_reserve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        pool_contract_address : felt, token_address : felt) -> (balance : Uint256):
    let (_token0) = IPool.get_token0(pool_contract_address)

    let (token0_reserve : Uint256, token1_reserve : Uint256) = IPool.get_reserves(
        pool_contract_address)

    if token_address == _token0:
        return (token0_reserve)
    else:
        return (token1_reserve)
    end
end

# @notice Given an output asset amount and token addresses, calculates all
# preceding minimum input token amounts.
# @param token_in_address : address of the input token
# @param token_out_address : address of the output token
# @param amount_out : the amount of the output token
# @return The minimum input token amounts.
@view
func get_amount_in{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_in_address : felt, token_out_address : felt, amount_out : Uint256) -> (
        amount_in : Uint256):
    alloc_locals

    let (pool_contract_address) = get_pool_address(token_in_address, token_out_address)

    verify_pool_is_whitelisted(pool_contract_address)

    let (reserve_out : Uint256) = get_pool_reserve(pool_contract_address, token_out_address)
    let (reserve_in : Uint256) = get_pool_reserve(pool_contract_address, token_in_address)

    let (enough_reserve_in) = uint256_lt(Uint256(0, 0), reserve_in)
    let (enough_reserve_out) = uint256_lt(Uint256(0, 0), reserve_out)

    assert (enough_reserve_in) = 1
    assert (enough_reserve_out) = 1

    let (reserve_in_mul_amount_out, _) = uint256_mul(reserve_in, amount_out)
    let (numerator, _) = uint256_mul(reserve_in_mul_amount_out, Uint256(1000, 0))

    let (reserve_out_sub_amount_out) = uint256_sub(reserve_out, amount_out)
    let (denominator, _) = uint256_mul(reserve_out_sub_amount_out, Uint256(997, 0))

    let (amount_in, _) = uint256_unsigned_div_rem(numerator, denominator)

    let (res, is_overflow) = uint256_add(amount_in, Uint256(1, 0))
    assert (is_overflow) = 0

    return (amount_in=res)
end

# @notice Given an input asset amount and  token addresses, calculates all
# subsequent maximum output token amounts.
# @param token_in_address : address of the input token
# @param token_out_address : address of the output token
# @param amount_in : the amount of the input token
# @return The maximum output token amounts.
@view
func get_amount_out{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_in_address : felt, token_out_address : felt, amount_in : Uint256) -> (
        amount_out : Uint256):
    alloc_locals

    let (pool_contract_address) = get_pool_address(token_in_address, token_out_address)

    verify_pool_is_whitelisted(pool_contract_address)

    let (reserve_out : Uint256) = get_pool_reserve(pool_contract_address, token_out_address)
    let (reserve_in : Uint256) = get_pool_reserve(pool_contract_address, token_in_address)

    let (enough_reserve_in) = uint256_lt(Uint256(0, 0), reserve_in)
    let (enough_reserve_out) = uint256_lt(Uint256(0, 0), reserve_out)

    assert (enough_reserve_in) = 1
    assert (enough_reserve_out) = 1

    let (amount_in_with_fee, _) = uint256_mul(amount_in, Uint256(997, 0))
    let (reserve_in_mul_1000, _) = uint256_mul(reserve_in, Uint256(1000, 0))

    let (numerator, _) = uint256_mul(amount_in_with_fee, reserve_out)

    let (denominator, _) = uint256_add(reserve_in_mul_1000, amount_in_with_fee)

    let (amount_out, _) = uint256_unsigned_div_rem(numerator, denominator)

    return (amount_out=amount_out)
end

func _swap{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount_in : Uint256, amount_out : Uint256, token_in_address : felt,
        token_out_address : felt, to : felt, pool_contract_address : felt) -> ():
    alloc_locals

    let (local token0) = IPool.get_token0(pool_contract_address)
    local token_out
    local amount1_out : Uint256
    local amount0_out : Uint256

    if token0 == token_out_address:
        assert amount0_out = amount_out
        assert amount1_out = Uint256(0, 0)
    else:
        assert amount0_out = Uint256(0, 0)
        assert amount1_out = amount_out
    end

    # swap
    IPool.swap(pool_contract_address, amount0_out, amount1_out, to, pool_contract_address)
    return ()
end

# @notice Swaps an exact amount of input tokens for as many output tokens as possible
# @param token_in_address : address of the input token
# @param token_out_address : address of the output token
# @param amount_in : the amount of the input token
# @param amount_out_min : The minimum amount of output tokens that must be received for t
# he transaction not to revert.
@external
func exact_input{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_in_address : felt, token_out_address : felt, amount_in : Uint256,
        amount_out_min : Uint256) -> ():
    alloc_locals

    let (pool_contract_address) = get_pool_address(token_in_address, token_out_address)

    verify_pool_is_whitelisted(pool_contract_address)

    # get amount out
    let (local amount_out : Uint256) = get_amount_out(
        token_in_address, token_out_address, amount_in)

    let (enough_amount_out) = uint256_le(amount_out_min, amount_out)
    assert (enough_amount_out) = 1

    let (local caller) = get_caller_address()
    IERC20.transferFrom(token_in_address, caller, pool_contract_address, amount_in)

    _swap(amount_in, amount_out, token_in_address, token_out_address, caller, pool_contract_address)

    return ()
end

# @notice Receive an exact amount of output tokens for as few input tokens as possible
# @param token_in_address : address of the input token
# @param token_out_address : address of the output token
# @param amount_out : The amount of output tokens to receive.
# @param amount_in_max : The maximum amount of input tokens that can be required before
# the transaction reverts.

@external
func exact_output{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        token_in_address : felt, token_out_address : felt, amount_out : Uint256,
        amount_in_max : Uint256) -> ():
    alloc_locals

    let (pool_contract_address) = get_pool_address(token_in_address, token_out_address)

    verify_pool_is_whitelisted(pool_contract_address)

    let (local amount_in : Uint256) = get_amount_in(token_in_address, token_out_address, amount_out)

    let (enough_amount_in) = uint256_le(amount_in, amount_in_max)
    assert (enough_amount_in) = 1

    let (local caller) = get_caller_address()
    IERC20.transferFrom(token_in_address, caller, pool_contract_address, amount_in)

    _swap(amount_in, amount_out, token_in_address, token_out_address, caller, pool_contract_address)

    return ()
end
