module publisher::DAT3PoolRoutel {
    use std::error;
    use std::signer;

    use aptos_framework::coin;

    use publisher::DAT3Pool;

    struct Users has key, store {
        uid: u64,
        fid: u64,
        freeze: u64,
        amount: u64,
    }

    const EINSUFFICIENT_BALANCE: u64 = 107u64;
    const NO_USER: u64 = 108u64;
    const NOT_FOUND: u64 = 110u64;
    const ALREADY_EXISTS: u64 = 111u64;


    public entry fun init<CoinType>(account: &signer, fid: u64, uid: u64)  {
        let user_address = signer::address_of(account);
        assert!(exists<Users>(user_address), error::already_exists(ALREADY_EXISTS));
        move_to(account, Users {
            uid,
            fid,
            freeze: 0u64,
            amount: 0u64,

        });
        DAT3Pool::init_pool<CoinType>(account);
    }


    // deposit token
    public entry fun deposit<CoinType: drop>(account: &signer, amount: u64) acquires Users {
        let user_address = signer::address_of(account);
        assert!(!exists<Users>(user_address), error::not_found(NO_USER));
        let astate = borrow_global_mut<Users>(user_address);
        let amount1 = astate.amount;
        astate.amount = amount1 + amount;
        let user_coin = coin::withdraw<CoinType>(account, amount);
        DAT3Pool::deposit<CoinType>( user_coin);
    }

    //Move compilation failed:
    public entry fun withdraw<CoinType: drop>(account: &signer, amount: u64) acquires Users {
        let user_address = signer::address_of(account);
        assert!(!exists<Users>(user_address), error::not_found(NO_USER));
        let astate = borrow_global_mut<Users>(user_address);
        let amount1 = astate.amount;
        assert!(amount1 < amount, error::out_of_range(EINSUFFICIENT_BALANCE));
        astate.amount = amount1 - amount;
        let user_coin = DAT3Pool::withdraw<CoinType>(amount);
        coin::deposit<CoinType>(user_address, user_coin);
    }

    public entry fun balance_of<CoinType: drop>(account: &signer):u64 acquires Users {
        let user_address = signer::address_of(account);
        assert!(!exists<Users>(user_address), error::not_found(NO_USER));
        let user = borrow_global<Users>(user_address) ;
        return user.amount
    }
    // // withdraw token
    // public entry fun withdraw<CoinType: drop>(account: &signer, amount: u64) acquires Pool {
    //     let user_address = signer::address_of(account);
    //     //no user error
    //     assert!(!exists<Pool<CoinType>>(user_address), error::not_found(NO_USER));
    //     //get address
    //     let account_addr = signer::address_of(account);
    //     //get mutable reference
    //     let astate = borrow_global_mut<Pool<CoinType>>(account_addr);
    //     //check amount
    //     assert!(amount >= coin::value(&mut astate.value), error::resource_exhausted(EINSUFFICIENT_BALANCE));
    //     //extract token
    //     let all_coins = coin::extract(&mut astate.value, amount);
    //     //withdraw amount
    //     coin::deposit<CoinType>(account_addr, all_coins);
    //     event::emit_event(&mut astate.withdraw_state_events, WithdrawStateEvent {
    //         uid: astate.uid, fid: astate.fid, value: amount
    //     });
    // }
    //
    // // get balance of coin
    // public fun balance_of<CoinType: drop>(owner: &signer): u64 acquires Pool {
    //     let user_address = signer::address_of(owner);
    //     assert!(!exists<Pool<CoinType>>(user_address), error::not_found(NO_USER));
    //     //get address
    //     let account_addr = signer::address_of(owner);
    //     //get mutable reference
    //     let astate = borrow_global<Pool<CoinType>>(account_addr);
    //     coin::value(&astate.value)
    // }
}