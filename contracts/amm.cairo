%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem
from starkware.starknet.common.syscalls import storage_read, storage_write

## @title AMM
## @description A minimalistic implementation of an AMM adapted from the StarkWare AMM.
## @author Alucard <github.com/a5f9t4>

#############################################
##               Constants                 ##
#############################################

## The upper bound of a balance ##
const BALANCE_UPPER_BOUND = 2 ** 64

const TOKEN_TYPE_A = 1
const TOKEN_TYPE_B = 2

## Prevents users balance > pool balance ##
const POOL_UPPER_BOUND = 2 ** 30
const ACCOUNT_BALANCE_BOUND = 1073741  # 2**30 // 1000.

#############################################
##                Storage                  ##
#############################################

## Gets the pool balance for a given token ##
@storage_var
func pool_balance(token_type : felt) -> (balance : felt):
end

## Gets the account balance for a given token ##
@storage_var
func account_balance(account_id : felt, token_type : felt) -> (
        balance : felt):
end

#############################################
##                Mutators                 ##
#############################################

## Updates an account's token balance ##
func modify_account_balance{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    account_id: felt,
    token_type: felt,
    amount: felt
):
    let (current_balance) = account_balance.read(
        account_id, token_type)
    tempvar new_balance = current_balance + amount
    assert_nn_le(new_balance, BALANCE_UPPER_BOUND - 1)
    account_balance.write(
        account_id=account_id,
        token_type=token_type,
        value=new_balance)
    return ()
end

func set_pool_token_balance{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr
}(
    token_type: felt,
    balance: felt
):
    assert_nn_le(balance, BALANCE_UPPER_BOUND - 1)
    pool_balance.write(token_type, balance)
    return ()
end

#############################################
##               Accessors                 ##
#############################################

## Get's the opposite token type ##
func get_opposite_token(
    token_type: felt
) -> (
    t : felt
):
    if token_type == TOKEN_TYPE_A:
        return (TOKEN_TYPE_B)
    else:
        return (TOKEN_TYPE_A)
    end
end

## Allows a user to the balance of account_id ##
@view
func get_account_token_balance{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    account_id: felt,
    token_type: felt
) -> (
    balance: felt
):
    return account_balance.read(account_id, token_type)
end

## Returns the balance of a pool ##
@view
func get_pool_token_balance{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    token_type: felt
) -> (
    balance: felt
):
    return pool_balance.read(token_type)
end

#############################################
##               Pool Logic                ##
#############################################

func swap{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    account_id: felt,
    token_from: felt,
    amount_from: felt
) -> (
    amount_to: felt
):
    assert (token_from - TOKEN_TYPE_A) * (token_from - TOKEN_TYPE_B) = 0
    assert_nn_le(amount_from, BALANCE_UPPER_BOUND - 1)
    let (account_from_balance) = get_account_token_balance(
        account_id=account_id, token_type=token_from)
    assert_le(amount_from, account_from_balance)
    let (token_to) = get_opposite_token(token_type=token_from)
    let (amount_to) = do_swap(
        account_id=account_id,
        token_from=token_from,
        token_to=token_to,
        amount_from=amount_from)
    return (amount_to=amount_to)
end

##################################################
##                Core Swap Logic               ##
##################################################
##                                              ##
##               amm_to_balance * amount_from   ##
##  amount_to = ------------------------------  ##
##              amm_from_balance + amount_from  ##
##                                              ##
##################################################
func do_swap{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    account_id: felt,
    token_from: felt,
    token_to: felt,
    amount_from: felt
) -> (
    amount_to : felt
):
    alloc_locals

    ## Get token balances in pool ##
    let (local amm_from_balance) = get_pool_token_balance(
        token_type=token_from)
    let (local amm_to_balance) = get_pool_token_balance(
        token_type=token_to)

    ## Perform Swap Calc ##
    let (local amount_to, _) = unsigned_div_rem(
        amm_to_balance * amount_from,
        amm_from_balance + amount_from)

    ## Update token_from balances ##
    modify_account_balance(
        account_id=account_id,
        token_type=token_from,
        amount=-amount_from
    )
    set_pool_token_balance(
        token_type=token_from,
        balance=amm_from_balance + amount_from
    )

    ## Update token_to balances ##
    modify_account_balance(
        account_id=account_id,
        token_type=token_to,
        amount=amount_to
    )
    set_pool_token_balance(
        token_type=token_to,
        balance=amm_to_balance - amount_to
    )
    return (amount_to=amount_to)
end

## Initializes a pool ##
@external
func init_pool{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    token_a: felt,
    token_b: felt
):
    assert_nn_le(token_a, POOL_UPPER_BOUND - 1)
    assert_nn_le(token_b, POOL_UPPER_BOUND - 1)

    set_pool_token_balance(token_type=TOKEN_TYPE_A, balance=token_a)
    set_pool_token_balance(token_type=TOKEN_TYPE_B, balance=token_b)

    return ()
end

## Creates a demo token ##
@external
func add_demo_token{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
}(
    account_id: felt,
    token_a_amount: felt,
    token_b_amount: felt
):
    assert_nn_le(token_a_amount, ACCOUNT_BALANCE_BOUND - 1)
    assert_nn_le(token_b_amount, ACCOUNT_BALANCE_BOUND - 1)

    modify_account_balance(
        account_id=account_id,
        token_type=TOKEN_TYPE_A,
        amount=token_a_amount)
    modify_account_balance(
        account_id=account_id,
        token_type=TOKEN_TYPE_B,
        amount=token_b_amount)

    return ()
end