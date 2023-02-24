module dat3::dat3_pool_routel {
    use std::error;
    use std::signer;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin;

    use dat3::dat3_coin::DAT3;
    use dat3::dat3_pool;
    use dat3::simple_mapv1::{Self, SimpleMapV1};

    struct Member has key, store {
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

    const ERR_NOT_ENOUGH_PERMISSIONS: u64 = 1000;
    const EINSUFFICIENT_BALANCE: u64 = 107u64;
    const NO_USER: u64 = 108u64;
    const NOT_FOUND: u64 = 110u64;
    const ALREADY_EXISTS: u64 = 111u64;

    struct CapHode has key {
        sigCap: SignerCapability,
    }

    public entry fun init(account: &signer)
    {
        let user_address = signer::address_of(account);
        assert!(user_address == @dat3, error::already_exists(ERR_NOT_ENOUGH_PERMISSIONS));
        assert!(!exists<UsersReward>(user_address), error::already_exists(ALREADY_EXISTS));
        assert!(!exists<UsersTotalConsumption>(user_address), error::already_exists(ALREADY_EXISTS));
        assert!(!exists<FidStore>(user_address), error::already_exists(ALREADY_EXISTS));
        move_to(account, UsersReward { data: simple_mapv1::create() });
        move_to(account, UsersTotalConsumption { data: simple_mapv1::create() });
        move_to(account, FidStore { data: simple_mapv1::create() });
        //move_to(account, CapHode { sigCap: dat3::dat3_coin_boot::retrieveResourceSignerCap(account) });
    }


    fun getSig(): signer acquires CapHode
    {
        account::create_signer_with_capability(&borrow_global<CapHode>(@dat3).sigCap)
    }

    public entry fun user_init<CoinType>(account: &signer, fid: u64, uid: u64)
    acquires UsersReward, UsersTotalConsumption
    {
        let user_address = signer::address_of(account);
        // todo check fid
        //cheak_fid
        assert!(cheak_fid(fid), error::not_found(ALREADY_EXISTS));
        assert!(!exists<Member>(user_address), error::already_exists(ALREADY_EXISTS));

        //init UsersReward
        let user_r = borrow_global_mut<UsersReward>(@dat3);
        if (!simple_mapv1::contains_key(&user_r.data, &user_address)) {
            simple_mapv1::add(&mut user_r.data, user_address, 0);
        };
        //init UsersTotalConsumption
        let user_t = borrow_global_mut<UsersTotalConsumption>(@dat3);
        if (!simple_mapv1::contains_key(&user_t.data, &user_address)) {
            simple_mapv1::add(&mut user_t.data, user_address, 0);
        };
        if (coin::is_account_registered<CoinType>(user_address)) {
            coin::register<CoinType>(account);
        };
        move_to(account, Member {
            uid,
            fid,
            freeze: 0u64,
            amount: 0u64,
        });
    }

    fun cheak_fid(fid: u64): bool {
        assert!(fid > 0, error::not_found(ALREADY_EXISTS));
        true
    }

    // deposit token
    public entry fun deposit<CoinType>(account: &signer, amount: u64) acquires Member {
        let user_address = signer::address_of(account);
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        let auser = borrow_global_mut<Member>(user_address);
        let user_amount = auser.amount;
        auser.amount = user_amount + amount;
        dat3_pool::deposit<CoinType>(account, amount);
    }

    //Move compilation failed:
    public entry fun withdraw<CoinType>(account: &signer, amount: u64) acquires Member {
        let user_address = signer::address_of(account);
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        let auser = borrow_global_mut<Member>(user_address);
        let user_amount = auser.amount;
        assert!(user_amount > amount, error::out_of_range(EINSUFFICIENT_BALANCE));
        auser.amount = user_amount - amount;
        dat3_pool::withdraw<CoinType>(user_address, amount);
    }


    public entry fun claim_reward(account: &signer, amount: u64) acquires UsersReward {
        let user_address = signer::address_of(account);
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        let user_r = borrow_global_mut<UsersReward>(@dat3);
        if (simple_mapv1::contains_key(&user_r.data, &user_address)) {
            let your = simple_mapv1::borrow_mut(&mut user_r.data, &user_address);
            assert!(amount < *your, error::out_of_range(EINSUFFICIENT_BALANCE));

            if (coin::is_account_registered<DAT3>(user_address)) {
                coin::register<DAT3>(account)
            };
            dat3_pool::withdraw_reward(user_address, amount);
            *your = *your - amount;
        };
    }

    public fun balance_of(account: &signer): (u64, u64) acquires Member, UsersReward {
        let user_address = signer::address_of(account);
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        let user = borrow_global<Member>(user_address) ;
        let user_r = borrow_global<UsersReward>(@dat3);
        let your: u64 = 0;
        if (simple_mapv1::contains_key(&user_r.data, &user_address)) {
            your = *simple_mapv1::borrow(&user_r.data, &user_address);
        };
        (user.amount, your)
    }


    #[test_only]
    use aptos_framework::aptos_account::create_account;
    #[test_only]
    use aptos_std::debug;

    #[test_only]
    use dat3::dat3_pool::init_pool;


    #[test(dat3 = @dat3)]
    fun dat3_coin_init(
        dat3: &signer
    ) acquires UsersReward, UsersTotalConsumption, Member {
        let addr = signer::address_of(dat3);
        create_account(addr);
        //init&register dat3_coin
        dat3::dat3_coin::init(dat3);
        coin::register<DAT3>(dat3);
        //init pool
        init_pool<DAT3>(dat3);
        //init dat3_pool_routel resources
        init(dat3);

        debug::print(&coin::balance<DAT3>(addr));
        user_init<DAT3>(dat3, 188, 199);
        let (a, b) = balance_of(dat3);
        debug::print(&a);
        debug::print(&b);
        deposit<DAT3>(dat3, 188);
        deposit<DAT3>(dat3, 2);
        let (a, b) = balance_of(dat3);
        debug::print(&a);
        debug::print(&b);

        withdraw<DAT3>(dat3, 179);
        let (a, b) = balance_of(dat3);
        debug::print(&a);
        debug::print(&b);
    }
}