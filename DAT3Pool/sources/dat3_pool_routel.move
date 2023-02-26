module dat3::dat3_pool_routel {
    use std::error;
    use std::signer;
    use std::vector;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin;

    use dat3::dat3_coin::DAT3;
    use dat3::dat3_pool;
    use dat3::simple_mapv1::{Self, SimpleMapV1};
    use aptos_framework::timestamp;

    struct Member has key, store {
        uid: u64,
        fid: u64,
        freeze: u64,
        amount: u64,
        mFee: u64,
    }

    struct FeeStore has key, store {
        chatFee: u64,
        mFee: SimpleMapV1<u64, u64>,
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

    struct Room has key, store {
        started_at: u64,
        finished_at: u64,
        max_duration: u64,
        minute_rate: u64,
        // price per minute
        receiver: address,
        deposit: u64,
        done: bool,
    }

    struct RoomState has key, store {
        data: SimpleMapV1<address, u8>,
    }

    const PERMISSION_DENIED: u64 = 1000;
    const EINSUFFICIENT_BALANCE: u64 = 107u64;
    const NO_USER: u64 = 108u64;
    const NO_TO_USER: u64 = 108u64;
    const NO_RECEIVER_USER: u64 = 108u64;
    const NOT_FOUND: u64 = 110u64;
    const ALREADY_EXISTS: u64 = 111u64;
    const OUT_OF_RANGE: u64 = 112;
    const INVALID_ARGUMENT: u64 = 113;
    const ALREADY_HAS_OPEN_SESSION: u64 = 200;
    const WHO_HAS_ALREADY_JOINED: u64 = 201;
    const YOU_HAS_ALREADY_JOINED: u64 = 201;
    const INVALID_RECEIVER: u64 = 202;
    const INVALID_REQUESTER: u64 = 202;

    struct CapHode has key {
        sigCap: SignerCapability,
    }

    public entry fun init(account: &signer)
    {
        let user_address = signer::address_of(account);
        assert!(user_address == @dat3, error::permission_denied(PERMISSION_DENIED));
        assert!(!exists<UsersReward>(user_address), error::already_exists(ALREADY_EXISTS));
        assert!(!exists<UsersTotalConsumption>(user_address), error::already_exists(ALREADY_EXISTS));
        assert!(!exists<FidStore>(user_address), error::already_exists(ALREADY_EXISTS));
        move_to(account, UsersReward { data: simple_mapv1::create() });
        move_to(account, UsersTotalConsumption { data: simple_mapv1::create() });
        move_to(account, FidStore { data: simple_mapv1::create() });
        let mFee = simple_mapv1::create();
        simple_mapv1::add(&mut mFee, 1, 2000000);
        simple_mapv1::add(&mut mFee, 2, 4000000);
        simple_mapv1::add(&mut mFee, 3, 10000000);
        simple_mapv1::add(&mut mFee, 4, 50000000);
        simple_mapv1::add(&mut mFee, 5, 100000000);
        move_to(account, FeeStore { chatFee: 1000000, mFee });
        move_to(account, RoomState { data: simple_mapv1::create() });

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
        assert!(cheak_fid(fid), error::invalid_argument(INVALID_ARGUMENT));
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
            mFee: 1,
        });
    }

    public fun fee_of_mine(user: &signer): (u64, u64) acquires FeeStore, Member {
        let user_address = signer::address_of(user);
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        let user_addr = signer::address_of(user);
        let is_me = borrow_global<Member>(user_addr);
        let fee = borrow_global<FeeStore>(@dat3);
        (is_me.mFee, *simple_mapv1::borrow(&fee.mFee, &is_me.mFee))
    }

    public fun change_my_fee(user: &signer, grade: u64): (u64, u64) acquires FeeStore, Member {
        let user_address = signer::address_of(user);
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        assert!(grade > 0 && grade <= 5, error::out_of_range(OUT_OF_RANGE));
        let user_addr = signer::address_of(user);
        let is_me = borrow_global_mut<Member>(user_addr);
        is_me.mFee = grade;
        let fee = borrow_global<FeeStore>(@dat3);
        (grade, *simple_mapv1::borrow(&fee.mFee, &is_me.mFee))
    }

    public fun change_sys_fee(user: &signer, grade: u64, fee: u64) acquires FeeStore {
        let user_address = signer::address_of(user);
        assert!(user_address == @dat3, error::permission_denied(PERMISSION_DENIED));
        assert!(grade > 0 && grade <= 5, error::out_of_range(OUT_OF_RANGE));
        assert!(fee > 0, error::out_of_range(OUT_OF_RANGE));
        let fee_s = borrow_global_mut<FeeStore>(@dat3);
        let old_fee = simple_mapv1::borrow_mut(&mut fee_s.mFee, &grade);
        *old_fee = fee;
    }

    public fun fee_of_all()
    : (u64, vector<u64>) acquires FeeStore
    {
        let fee = borrow_global<FeeStore>(@dat3);
        let vl = vector::empty<u64>();
        vector::push_back(&mut vl, *simple_mapv1::borrow(&fee.mFee, &1));
        vector::push_back(&mut vl, *simple_mapv1::borrow(&fee.mFee, &2));
        vector::push_back(&mut vl, *simple_mapv1::borrow(&fee.mFee, &3));
        vector::push_back(&mut vl, *simple_mapv1::borrow(&fee.mFee, &4));
        vector::push_back(&mut vl, *simple_mapv1::borrow(&fee.mFee, &5));
        (fee.chatFee, vl)
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

    public entry fun call_1(account: &signer, to: address) acquires Member, FeeStore, UsersTotalConsumption {
        let user_address = signer::address_of(account);
        // check users
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        assert!(exists<Member>(to), error::not_found(NO_TO_USER));
        //get fee
        let fee_s = borrow_global<FeeStore>(@dat3);
        //get A userinfo
        let auser = borrow_global_mut<Member>(user_address);
        //check balance
        assert!(auser.amount > fee_s.chatFee, error::out_of_range(EINSUFFICIENT_BALANCE));
        //change user A's balance , that it subtracts fee
        auser.amount = auser.amount - fee_s.chatFee;
        //get B userinfo
        let buser = borrow_global_mut<Member>(to);
        //change user B's balance , that it add fee*0.7
        //todo Modify Fee Scale
        buser.amount = buser.amount + ((fee_s.chatFee * 70 as u128) / (100u128) as u64);
        //and A Total Consumption add chatFee
        let total = borrow_global_mut<UsersTotalConsumption>(@dat3);
        let map = total.data;
        let your = simple_mapv1::borrow_mut(&mut map, &user_address);
        *your = *your + fee_s.chatFee;
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

    fun assert_room_state(addr: address): u8 acquires RoomState {
        let data = borrow_global<RoomState>(@dat3) ;
        *simple_mapv1::borrow(&data.data, &addr)
    }

    fun room_state(addr: address, state: u8) acquires RoomState {
        let data = borrow_global_mut<RoomState>(@dat3) ;
        if (!simple_mapv1::contains_key(&data.data, &addr)) {
            simple_mapv1::add(&mut data.data, addr, state);
        }else {
            let s = simple_mapv1::borrow_mut(&mut data.data, &addr);
            *s = state;
        };
    }

    fun room_state_change(addr: address, state: u8) acquires RoomState {
        let data = borrow_global_mut<RoomState>(@dat3) ;
        let s = simple_mapv1::borrow_mut(&mut data.data, &addr);
        *s = state;
    }

    // 1. A requester can initiate a payment stream session for a video call.
    public entry fun create_rome(
        requester: &signer,
        duration: u64,
        receiver: address
    ) acquires Room, Member, FeeStore, RoomState {
        let requester_addr = signer::address_of(requester);
        //check user
        assert!(exists<Member>(requester_addr), error::not_found(NO_USER));
        assert!(exists<Member>(receiver), error::not_found(NO_RECEIVER_USER));
        //get req_member
        let req_member = borrow_global_mut<Member>(requester_addr) ;
        //get fee
        let fee_store = borrow_global<FeeStore>(receiver) ;
        let fee = simple_mapv1::borrow(&fee_store.mFee, &req_member.mFee);
        //get max_duration
        let max_duration = (((req_member.amount as u128) / (*fee as u128)) as u64);
        assert!(duration <= max_duration, error::invalid_argument(EINSUFFICIENT_BALANCE));
        let deposit = *fee * duration;
        //extract amount
        req_member.amount = req_member.amount - deposit;
        //Deposit funds to rome extract amount
        if (exists<Room>(requester_addr)) {
            let session = borrow_global_mut<Room>(requester_addr);
            assert!(session.done, error::invalid_state(ALREADY_HAS_OPEN_SESSION));

            // Overwrite the finished session
            session.started_at = 0;
            session.finished_at = 0;
            session.max_duration = duration;
            session.minute_rate = *fee;
            session.receiver = receiver;
            session.deposit = deposit;
            session.done = false;
        } else {
            move_to(requester, Room {
                started_at: 0,
                finished_at: 0,
                max_duration: duration,
                minute_rate: *fee,
                receiver,
                deposit,
                done: false,
            })
        };
        room_state(requester_addr, 1);
        room_state(receiver, 0);
    }

    // 2. The receiver can join the session through the video call link
    public entry fun join_room(receiver: &signer, requester: address) acquires Room, RoomState {
        let receiver_addr = signer::address_of(receiver);
        assert!(exists<Member>(receiver_addr), error::not_found(NO_USER));
        assert!(exists<Member>(requester), error::not_found(NO_USER));
        assert!(exists<Room>(requester), error::invalid_state(INVALID_REQUESTER));
        let req_session = borrow_global_mut<Room>(requester);
        //check req state
        assert!(req_session.started_at == 0, error::invalid_state(WHO_HAS_ALREADY_JOINED));
        //check receiver
        assert!(req_session.receiver == receiver_addr, error::invalid_state(INVALID_RECEIVER));
        //check rec state
        assert!(assert_room_state(receiver_addr) == 0, error::invalid_state(YOU_HAS_ALREADY_JOINED));
        room_state(receiver_addr, 2);
        req_session.started_at = timestamp::now_seconds()
    }

    // 3. Upon closing of the session, send payment to the receiver, and refund any remaining funds to the requester
    public entry fun close_room(
        account: &signer,
        requester: address,
        receiver: address
    ) acquires Room, Member, RoomState {
        let account_addr = signer::address_of(account);

        assert!(exists<Member>(receiver), error::not_found(NO_USER));
        assert!(exists<Member>(requester), error::not_found(NO_USER));
        assert!(exists<Room>(requester), error::invalid_state(INVALID_RECEIVER));
        let req = borrow_global_mut<Room>(receiver);
        assert!(account_addr == requester || account_addr == req.receiver, error::invalid_state(INVALID_RECEIVER));
        assert!(req.started_at > 0 && req.finished_at == 0, error::invalid_state(INVALID_RECEIVER));
        let now_s = timestamp::now_seconds();
        let duration_s = ((now_s - req.started_at) as u128);
        let duration_m = ((duration_s / 60u128) as u64);
        let temp = ((duration_s % 60u128) as u64);
        if (temp > 0) {
            duration_m = duration_m + 1;
        };
        if (req.max_duration <= duration_m) {
            duration_m = req.max_duration;
        };
        //to return req.deposit
        req.deposit = req.deposit - (duration_m * req.minute_rate);
        req.finished_at = now_s;
        req.done = true;
        let req_user = borrow_global_mut<Member>(receiver);
        req_user.amount = req_user.amount + req.deposit ;

        room_state_change(requester, 0);
        room_state_change(receiver, 0);
    }

    #[view]
    public fun remaining_time(requester: address): (u64, u64, u64, u64, address, u64, bool) acquires Room {
        let session = borrow_global<Room>(requester);
        (session.started_at, session.finished_at, session.max_duration, session.minute_rate, session.receiver, session.deposit, session.done)
    }
    // #[test_only]
    // use aptos_std::debug;
    // #[test_only]
    // use aptos_framework::aptos_account::create_account;
    // #[test_only]
    // use dat3::dat3_pool::init_pool;

    // #[test(dat3 = @dat3)]
    // fun dat3_coin_init(
    //     dat3: &signer
    // ) acquires UsersReward, UsersTotalConsumption, Member, FeeStore {
    //     let addr = signer::address_of(dat3);
    //     create_account(addr);
    //     //init&register dat3_coin
    //     dat3::dat3_coin::init(dat3);
    //     coin::register<DAT3>(dat3);
    //     //init pool
    //     init_pool<DAT3>(dat3);
    //     //init dat3_pool_routel resources
    //     init(dat3);
    //
    //     debug::print(&coin::balance<DAT3>(addr));
    //     user_init<DAT3>(dat3, 188, 199);
    //     let (a, b) = balance_of(dat3);
    //     debug::print(&a);
    //     debug::print(&b);
    //     deposit<DAT3>(dat3, 188);
    //     deposit<DAT3>(dat3, 2);
    //     let (a, b) = balance_of(dat3);
    //     debug::print(&a);
    //     debug::print(&b);
    //
    //     withdraw<DAT3>(dat3, 179);
    //     let (a, b) = balance_of(dat3);
    //     debug::print(&a);
    //     debug::print(&b);
    // }
}