%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_check, uint256_le, uint256_sub)
from starkware.starknet.common.syscalls import get_caller_address

# Storage.

@storage_var
func _governance_address() -> (res : felt):
end

@storage_var
func _permitted_minter() -> (res : felt):
end

@storage_var
func _name() -> (res : felt):
end

@storage_var
func _symbol() -> (res : felt):
end

@storage_var
func _decimals() -> (res : felt):
end

@storage_var
func total_supply() -> (res : Uint256):
end

@storage_var
func balances(account : felt) -> (res : Uint256):
end

@storage_var
func allowances(owner : felt, spender : felt) -> (res : Uint256):
end

# Constructor.

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        name : felt, symbol : felt, governance_account_address : felt):
    _name.write(name)
    _symbol.write(symbol)
    _decimals.write(18)
    assert_not_zero(governance_account_address)
    _governance_address.write(governance_account_address)

    _mint(governance_account_address, Uint256(1000000000000000000000000000000, 0))
    return ()
end

# Getters.

@view
func governance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        governance : felt):
    let (governance) = _governance_address.read()
    return (governance)
end

@view
func permittedMinter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        minter : felt):
    let (minter) = _permitted_minter.read()
    return (minter)
end

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = _name.read()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = _symbol.read()
    return (symbol)
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        totalSupply : Uint256):
    let (totalSupply : Uint256) = total_supply.read()
    return (totalSupply)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        decimals : felt):
    let (decimals) = _decimals.read()
    return (decimals)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt) -> (balance : Uint256):
    let (balance : Uint256) = balances.read(account=account)
    return (balance)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, spender : felt) -> (remaining : Uint256):
    let (remaining : Uint256) = allowances.read(owner=owner, spender=spender)
    return (remaining)
end

# Externals.

@external
func setPermittedMinter{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        minter_address : felt):
    alloc_locals
    # Is governance.
    let (caller_address) = get_caller_address()
    let (local governance_address) = governance()
    assert caller_address = governance_address

    # Is not initialized.
    let (local currently_stored_address) = permittedMinter()
    assert currently_stored_address = 0

    # Set new value.
    local syscall_ptr : felt* = syscall_ptr
    assert_not_zero(minter_address)
    _permitted_minter.write(value=minter_address)
    return ()
end

@external
func permissionedMint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : Uint256):
    # Only the permittedMinter is allowed to call this function.
    alloc_locals
    let (local caller_address) = get_caller_address()
    let (local permitted_address) = permittedMinter()
    assert_not_zero(permitted_address)
    assert caller_address = permitted_address
    local syscall_ptr : felt* = syscall_ptr
    _mint(recipient=recipient, amount=amount)
    return ()
end

@external
func permissionedBurn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt, amount : Uint256):
    alloc_locals
    # Only the permittedMinter is allowed to call this function.
    let (local caller_address) = get_caller_address()
    let (local permitted_address) = permittedMinter()
    assert_not_zero(permitted_address)
    assert caller_address = permitted_address
    local syscall_ptr : felt* = syscall_ptr
    _burn(account=account, amount=amount)
    return ()
end

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : Uint256) -> (success : felt):
    let (sender) = get_caller_address()
    _transfer(sender, recipient, amount)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    alloc_locals
    let (local caller) = get_caller_address()
    let (local caller_allowance : Uint256) = allowances.read(owner=sender, spender=caller)

    # Validates amount <= caller_allowance and returns 1 if true.
    let (enough_balance) = uint256_le(amount, caller_allowance)
    assert_not_zero(enough_balance)

    _transfer(sender, recipient, amount)

    # Subtract allowance.
    let (new_allowance : Uint256) = uint256_sub(caller_allowance, amount)
    allowances.write(sender, caller, new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, amount : Uint256) -> (success : felt):
    let (caller) = get_caller_address()
    _approve(caller, spender, amount)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func increaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, added_value : Uint256) -> (success : felt):
    alloc_locals
    uint256_check(added_value)
    let (local caller) = get_caller_address()
    let (local current_allowance : Uint256) = allowances.read(caller, spender)

    # Add allowance.
    let (local new_allowance : Uint256, is_overflow) = uint256_add(current_allowance, added_value)
    assert (is_overflow) = 0

    _approve(caller, spender, new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

@external
func decreaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, subtracted_value : Uint256) -> (success : felt):
    alloc_locals
    uint256_check(subtracted_value)
    let (local caller) = get_caller_address()
    let (local current_allowance : Uint256) = allowances.read(owner=caller, spender=spender)
    let (local new_allowance : Uint256) = uint256_sub(current_allowance, subtracted_value)

    # Validates new_allowance <= current_allowance and returns 1 if true.
    let (enough_allowance) = uint256_le(new_allowance, current_allowance)
    assert_not_zero(enough_allowance)

    _approve(caller, spender, new_allowance)

    # Cairo equivalent to 'return (true)'
    return (1)
end

# Internals.

func _mint{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : Uint256):
    alloc_locals
    assert_not_zero(recipient)
    uint256_check(amount)

    let (balance : Uint256) = balances.read(account=recipient)
    # Overflow is not possible because sum is guaranteed to be less than total supply
    # which we check for overflow below.
    let (new_balance : Uint256, _ : felt) = uint256_add(balance, amount)
    balances.write(recipient, new_balance)

    let (local supply : Uint256) = total_supply.read()
    let (local new_supply : Uint256, is_overflow) = uint256_add(supply, amount)
    assert (is_overflow) = 0

    total_supply.write(new_supply)
    return ()
end

func _transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, recipient : felt, amount : Uint256):
    alloc_locals
    assert_not_zero(sender)
    assert_not_zero(recipient)
    uint256_check(amount)  # Almost surely not needed, might remove after confirmation.

    let (local sender_balance : Uint256) = balances.read(account=sender)

    # Validates amount <= sender_balance and returns 1 if true.
    let (enough_balance) = uint256_le(amount, sender_balance)
    assert_not_zero(enough_balance)

    # Subtract from sender.
    let (new_sender_balance : Uint256) = uint256_sub(sender_balance, amount)
    balances.write(sender, new_sender_balance)

    # Add to recipient.
    let (recipient_balance : Uint256) = balances.read(account=recipient)
    # Overflow is not possible because sum is guaranteed by mint to be less than total supply.
    let (new_recipient_balance : Uint256, _ : felt) = uint256_add(recipient_balance, amount)
    balances.write(recipient, new_recipient_balance)
    return ()
end

func _approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        caller : felt, spender : felt, amount : Uint256):
    assert_not_zero(caller)
    assert_not_zero(spender)
    uint256_check(amount)
    allowances.write(caller, spender, amount)
    return ()
end

func _burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt, amount : Uint256):
    alloc_locals
    assert_not_zero(account)
    uint256_check(amount)

    let (balance : Uint256) = balances.read(account)
    # Validates amount <= balance and returns 1 if true.
    let (enough_balance) = uint256_le(amount, balance)
    assert_not_zero(enough_balance)

    let (new_balance : Uint256) = uint256_sub(balance, amount)
    balances.write(account, new_balance)

    let (supply : Uint256) = total_supply.read()
    let (new_supply : Uint256) = uint256_sub(supply, amount)
    total_supply.write(new_supply)
    return ()
end
