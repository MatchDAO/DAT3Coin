module publisher::dat3_pool_routel {
    use std::error;
    use std::signer;
    use aptos_framework::coin;

    use publisher::dat3_pool;
    use publisher::simple_mapv1::{Self, SimpleMapV1};

    struct Users has key, store {
        uid: u64,
        fid: u64,
        freeze: u64,
        amount: u64,
    }

    struct UsersReward has key, store {
        data: SimpleMapV1<address, u64>,
    }

    //Total daily consumption of users
    struct UsersTotalConsumption has key, store {
        data: SimpleMapV1<address, u64>,
    }

    struct FidStore has key, store {
        data: SimpleMapV1<u64, u64>,
    }

    const EINSUFFICIENT_BALANCE: u64 = 107u64;
    const NO_USER: u64 = 108u64;
    const NOT_FOUND: u64 = 110u64;
    const ALREADY_EXISTS: u64 = 111u64;


    public entry fun user_init<CoinType>(
        account: &signer,
        fid: u64,
        uid: u64
    ) acquires UsersReward, UsersTotalConsumption {
        let user_address = signer::address_of(account);
        // todo check fid
        //cheak_fid
        assert!(cheak_fid(fid) , error::not_found(ALREADY_EXISTS));
        assert!(exists<Users>(user_address), error::already_exists(ALREADY_EXISTS));

        //init UsersReward
        let user_r = borrow_global_mut<UsersReward>(@publisher);
        simple_mapv1::add(*user_r.data, user_address, 0);

        //init UsersTotalConsumption
        let user_t = borrow_global_mut<UsersTotalConsumption>(@publisher);
        simple_mapv1::add(*user_t.data, user_address, 0);

        move_to(account, Users {
            uid,
            fid,
            freeze: 0u64,
            amount: 0u64,
        });
    }

    fun cheak_fid( fid: u64):bool{
        true
    }
    // deposit token
    public entry fun deposit<CoinType: drop>(account: &signer, amount: u64) acquires Users {
        let user_address = signer::address_of(account);
        assert!(!exists<Users>(user_address), error::not_found(NO_USER));
        let auser = borrow_global_mut<Users>(user_address);
        let user_amount = auser.amount;
        astate.amount = user_amount + amount;
        let user_coin = coin::withdraw<CoinType>(account, amount);
        dat3_pool::deposit<CoinType>(user_coin);
    }

    //Move compilation failed:
    public entry fun withdraw<CoinType: drop>(account: &signer, amount: u64) acquires Users {
        let user_address = signer::address_of(account);
        assert!(!exists<Users>(user_address), error::not_found(NO_USER));
        let auser = borrow_global_mut<Users>(user_address);
        let user_amount = auser.amount;
        assert!(user_amount < amount, error::out_of_range(EINSUFFICIENT_BALANCE));
        auser.amount = user_amount - amount;
        let user_coin = dat3_pool::withdraw<CoinType>(amount);
        coin::deposit<CoinType>(user_address, user_coin);
    }

    public entry fun balance_of<CoinType: drop>(account: &signer): (u64, u64) acquires Users, UsersReward {
        let user_address = signer::address_of(account);
        assert!(!exists<Users>(user_address), error::not_found(NO_USER));
        let user = borrow_global<Users>(user_address) ;
        let users_reward = borrow_global<UsersReward>(user_address) ;
        (user.amount, 0)
    }

}