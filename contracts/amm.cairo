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
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        account_id : felt, token_type : felt, amount : felt):
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


