module dat3::dat3_pool_routel {
    use std::error;
    use std::signer;
    use std::vector;

    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::coin;
    use aptos_framework::timestamp;

    use dat3::dat3_coin::DAT3;
    use dat3::dat3_pool;
    use dat3::simple_mapv1::{Self, SimpleMapV1};
    use aptos_token::token;
    use std::string::String;
    use dat3::dat3_stake::GenesisInfo;

    struct Member has key, store {
        uid: u64,
        fid: u64,
        freeze: u64,
        amount: u64,
        mFee: u64,
        earn: u64,
    }

    struct FeeStore has key, store {
        invite_reward_fee_den: u128,
        invite_reward_fee_num: u128,
        chatFee: u64,
        mFee: SimpleMapV1<u64, u64>,
    }

    struct MsgSender has key, store {
        serders: vector<address>
    }

    struct MsgHoder has key, store {
        receiver: SimpleMapV1<address, vector<u64>>
    }

    struct UsersReward has key, store {
        data: SimpleMapV1<address, Reward>,
    }

    struct Reward has drop, key, store {
        reward: u64,
        claim: u64,
        every_reward: vector<u64>,
        every_reward_time: vector<u64>,

        //Invalid variable usage. Unbound variable 'pool_info'
    }

    //Total daily consumption of users
    struct UsersTotalConsumption has key, store {
        data: SimpleMapV1<address, u64>,
    }

    struct FidStore has key, store {
        data: SimpleMapV1<u64, FidReward>,
    }

    struct FidReward has key, store, drop {
        token: String,
        collection: String,
        fid: u64,
        spend: u64,
        earn: u64,
        users: vector<address>,
        all: u64,
        amount: u64,
    }


    struct Room has key, store {
        addr: address,
        started_at: u64,
        finished_at: u64,
        minute_rate: u64,
        minute: u64,
        // price per minute
        receiver: address,
        deposit: u64,
        done: bool,
    }

    struct RoomState has key, store {
        data: SimpleMapV1<address, u8>,
    }


    //half of the day
    const SECONDS_OF_12HOUR: u64 = 43200 ;

    const PERMISSION_DENIED: u64 = 1000;

    const INVALID_ARGUMENT: u64 = 105;
    const OUT_OF_RANGE: u64 = 106;
    const EINSUFFICIENT_BALANCE: u64 = 107;
    const NO_USER: u64 = 108;
    const NO_TO_USER: u64 = 109;
    const NO_RECEIVER_USER: u64 = 110;
    const NOT_FOUND: u64 = 111;
    const ALREADY_EXISTS: u64 = 112;

    const ALREADY_HAS_OPEN_SESSION: u64 = 300;
    const WHO_HAS_ALREADY_JOINED: u64 = 301;
    const YOU_HAS_ALREADY_JOINED: u64 = 302;
    const INVALID_RECEIVER: u64 = 303;
    const INVALID_REQUESTER: u64 = 304;
    const INVALID_ROOM_STATE: u64 = 305;
    const INVALID_ID: u64 = 400;

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
        move_to(account, UsersReward { data: simple_mapv1::create<address, Reward>() });
        move_to(account, UsersTotalConsumption { data: simple_mapv1::create<address, u64>() });
        move_to(account, FidStore { data: simple_mapv1::create<u64, FidReward>() });
        let mFee = simple_mapv1::create<u64, u64>();
        simple_mapv1::add(&mut mFee, 1, 2000000);
        simple_mapv1::add(&mut mFee, 2, 4000000);
        simple_mapv1::add(&mut mFee, 3, 10000000);
        simple_mapv1::add(&mut mFee, 4, 50000000);
        simple_mapv1::add(&mut mFee, 5, 100000000);
        move_to(account, FeeStore { invite_reward_fee_den: 10000, invite_reward_fee_num: 500, chatFee: 1000000, mFee });

        move_to(account, RoomState { data: simple_mapv1::create<address, u8>() });
        move_to(account, MsgSender { serders: vector::empty<address>() });

        //
        // let module_authority = dat3_coin_boot::retrieveResourceSignerCap(account);
        // move_to(&account::create_signer_with_capability(&module_authority), Member {
        //     uid: 101,
        //     fid: 1002,
        //     freeze: 0,
        //     amount: 0,
        //     mFee: 1,
        // });
    }


    fun getSig(): signer acquires CapHode
    {
        account::create_signer_with_capability(&borrow_global<CapHode>(@dat3).sigCap)
    }

    public entry fun user_init(
        account: &signer,
        fid: u64,
        uid: u64
    ) acquires FidStore, UsersReward, UsersTotalConsumption
    {
        let user_address = signer::address_of(account);
        //cheak_fid
        assert!(fid > 0, error::invalid_argument(INVALID_ID));
        let fs = borrow_global_mut<FidStore>(@dat3);

        assert!(simple_mapv1::contains_key(&fs.data, &fid), error::invalid_argument(INVALID_ARGUMENT));

        //init UsersReward
        let user_r = borrow_global_mut<UsersReward>(@dat3);
        if (!simple_mapv1::contains_key(&user_r.data, &user_address)) {
            simple_mapv1::add(&mut user_r.data, user_address, Reward {
                reward: 0, claim: 0, every_reward: vector::empty<u64>(), every_reward_time: vector::empty<u64>()
            });
        };
        //init UsersTotalConsumption
        let user_t = borrow_global_mut<UsersTotalConsumption>(@dat3);
        if (!simple_mapv1::contains_key(&user_t.data, &user_address)) {
            simple_mapv1::add(&mut user_t.data, user_address, 0);
        };
        if (!coin::is_account_registered<0x1::aptos_coin::AptosCoin>(user_address)) {
            coin::register<0x1::aptos_coin::AptosCoin>(account);
        };
        if (!coin::is_account_registered<DAT3>(user_address)) {
            coin::register<DAT3>(account);
        };
        if (!exists<MsgSender>(user_address)) {
            move_to(account, MsgSender { serders: vector::empty<address>() });
        };
        if (!exists<MsgHoder>(user_address)) {
            move_to(account, MsgHoder { receiver: simple_mapv1::create<address, vector<u64>>() });
        };

        let fidr = simple_mapv1::borrow_mut(&mut fs.data, &fid);
        if (!vector::contains(&mut fidr.users, &user_address)) {
            vector::push_back(&mut fidr.users, user_address);
        };
        if (!exists<Member>(user_address)) {
            move_to(account, Member {
                uid,
                fid,
                freeze: 0u64,
                amount: 0u64,
                mFee: 1,
                earn: 0
            });
        };
    }

    #[view]
    public fun fee_of_mine(user: address): (u64, u64, u64) acquires FeeStore, Member
    {
        assert!(exists<Member>(user), error::not_found(NO_USER));

        let is_me = borrow_global<Member>(user);
        let fee = borrow_global<FeeStore>(@dat3);
        (fee.chatFee, is_me.mFee, *simple_mapv1::borrow(&fee.mFee, &is_me.mFee))
    }

    #[view]
    public fun fee_of_all(): (u64, vector<u64>) acquires FeeStore
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

    //Transaction Executed and Committed with Error INVALID MAIN FUNCTION SIGNATURE
    public entry fun change_my_fee(user: &signer, grade: u64) acquires Member
    {
        let user_address = signer::address_of(user);
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        assert!(grade > 0 && grade <= 5, error::out_of_range(OUT_OF_RANGE));
        let user_addr = signer::address_of(user);
        let is_me = borrow_global_mut<Member>(user_addr);
        is_me.mFee = grade;
    }

    public entry fun change_sys_fee(user: &signer, grade: u64, fee: u64, cfee: u64) acquires FeeStore
    {
        let user_address = signer::address_of(user);
        assert!(user_address == @dat3, error::permission_denied(PERMISSION_DENIED));
        assert!(grade > 0 && grade <= 5, error::out_of_range(OUT_OF_RANGE));
        assert!(fee > 0, error::out_of_range(OUT_OF_RANGE));
        let fee_s = borrow_global_mut<FeeStore>(@dat3);
        if (cfee > 0) {
            fee_s.chatFee = cfee;
        };
        if (grade > 0) {
            let old_fee = simple_mapv1::borrow_mut(&mut fee_s.mFee, &grade);
            *old_fee = fee;
        };
    }

    public entry fun change_sys_fid(user: &signer, fid: u64, del: bool, token: String, collection: String)
    acquires FidStore
    {
        let user_address = signer::address_of(user);
        assert!(user_address == @dat3, error::permission_denied(PERMISSION_DENIED));
        assert!(exists<FidStore>(@dat3), error::permission_denied(PERMISSION_DENIED));
        let f = borrow_global_mut<FidStore>(@dat3);

        let contains = simple_mapv1::contains_key(&f.data, &fid);
        if (contains) {
            let fr = simple_mapv1::borrow_mut(&mut f.data, &fid);
            if (del) {
                assert!(fr.amount == 0
                    && vector::length(&fr.users) == 0
                    && fr.earn == 0
                    && fr.spend == 0
                    && fr.amount == 0, error::permission_denied(ALREADY_EXISTS));
                simple_mapv1::remove(&mut f.data, &fid);
            }else {
                fr.collection = collection;
                fr.token = token;
            };
        }else {
            if (!del) {
                simple_mapv1::add(&mut f.data, fid, FidReward {
                    token,
                    collection,
                    fid: fid,
                    spend: 0,
                    earn: 0,
                    users: vector::empty<address>(),
                    all: 0,
                    amount: 0,
                });
            };
        };
    }

    #[view]
    public fun fid_reward(fid: u64): (u64, u64, u64, u64, u64, u64, ) acquires FidStore
    {
        assert!(exists<FidStore>(@dat3), error::not_found(NOT_FOUND));
        let f = borrow_global<FidStore>(@dat3);
        if (simple_mapv1::contains_key(&f.data, &fid)) {
            let fr = simple_mapv1::borrow(&f.data, &fid);
            return (fr.fid, fr.amount, fr.spend, fr.earn, vector::length(&fr.users), fr.all)
        };
        return (0, 0, 0, 0, 0, 0)
    }

    #[view]
    public fun fid_reward_invite(fid: u64): vector<address> acquires FidStore
    {
        assert!(exists<FidStore>(@dat3), error::not_found(NOT_FOUND));
        let f = borrow_global<FidStore>(@dat3);
        if (simple_mapv1::contains_key(&f.data, &fid)) {
            let fr = simple_mapv1::borrow(&f.data, &fid);
            return fr.users
        };
        return vector::empty<address>()
    }

    fun cheak_fid(fid: u64): bool acquires FidStore
    {
        assert!(fid > 0, error::invalid_argument(INVALID_ID));
        let fs = borrow_global<FidStore>(@dat3);
        simple_mapv1::contains_key(&fs.data, &fid)
    }

    // deposit token
    public entry fun deposit(account: &signer, amount: u64) acquires Member
    {
        let user_address = signer::address_of(account);
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        let auser = borrow_global_mut<Member>(user_address);
        let user_amount = auser.amount;
        auser.amount = user_amount + amount;
        dat3_pool::deposit(account, amount);
    }

    //Move compilation failed:
    public entry fun withdraw(account: &signer, amount: u64) acquires Member
    {
        let user_address = signer::address_of(account);
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        let auser = borrow_global_mut<Member>(user_address);
        let user_amount = auser.amount;
        assert!(user_amount > amount, error::out_of_range(EINSUFFICIENT_BALANCE));
        auser.amount = user_amount - amount;
        dat3_pool::withdraw(user_address, amount);
    }

    #[view]
    public fun is_sender(sender: address, to: address): u64 acquires MsgSender
    {
        assert!(exists<Member>(sender), error::not_found(NO_USER));
        assert!(exists<Member>(to), error::not_found(NO_TO_USER));
        assert!(exists<MsgSender>(to), error::not_found(NO_TO_USER));
        assert!(exists<MsgSender>(sender), error::not_found(NO_TO_USER));
        let m1 = borrow_global<MsgSender>(to);
        let m2 = borrow_global<MsgSender>(sender);
        //is
        if (vector::contains(&m1.serders, &sender)) {
            return 1u64
        };
        //no
        if (vector::contains(&m2.serders, &to)) {
            return 2u64
        };
        //is
        return 3u64
    }

    public entry fun call_1(account: &signer, to: address)
    acquires Member, FeeStore, UsersTotalConsumption, MsgSender, MsgHoder, FidStore
    {
        let user_address = signer::address_of(account);
        // check users
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        assert!(exists<Member>(to), error::not_found(NO_TO_USER));
        assert!(user_address != to, error::not_found(NO_TO_USER));
        //get fee
        let fee_s = borrow_global<FeeStore>(@dat3);

        let auser = borrow_global_mut<Member>(user_address);

        let is_sender = is_sender(user_address, to);
        //is_sender Deduction chatFee and add TotalConsumption
        if (is_sender == 1 || is_sender == 3) {
            //add sender
            if (is_sender == 3) {
                let msg_sender = borrow_global_mut<MsgSender>(to);
                vector::push_back(&mut msg_sender.serders, user_address)
            };
            //Record the time of each message
            let msg_hoder = borrow_global_mut<MsgHoder>(to);
            if (simple_mapv1::contains_key(&msg_hoder.receiver, &user_address)) {
                vector::push_back(
                    simple_mapv1::borrow_mut(&mut msg_hoder.receiver, &user_address),
                    timestamp::now_seconds()
                )
            }else {
                let vec = vector::empty<u64>();
                vector::push_back(&mut vec, timestamp::now_seconds());
                simple_mapv1::add(&mut msg_hoder.receiver, user_address, vec);
            };
            //check balance
            assert!(auser.amount >= fee_s.chatFee, error::out_of_range(EINSUFFICIENT_BALANCE));
            //change user A's balance , that it subtracts fee
            auser.amount = auser.amount - fee_s.chatFee;
            //and A Total Consumption add chatFee
            let total = borrow_global_mut<UsersTotalConsumption>(@dat3);
            let your = simple_mapv1::borrow_mut(&mut total.data, &user_address);
            *your = *your + fee_s.chatFee;
            //fid_re(fid: u64, den: u128, num: u128, amount: u64, s: bool)

            fid_re(auser.fid, fee_s.invite_reward_fee_den, fee_s.invite_reward_fee_num, fee_s.chatFee, true);
        }else {
            //is receiver
            //get msg_hoder of sender
            let msg_hoder = borrow_global_mut<MsgHoder>(user_address);
            let vec = simple_mapv1::borrow_mut(&mut msg_hoder.receiver, &to);
            let leng = vector::length(vec);
            if (leng > 0) {
                let i = 0u64;
                let re = 0u64;
                let now = timestamp::now_seconds();
                while (i < leng) {
                    //Effective time
                    if ((now - *vector::borrow<u64>(vec, i)) < SECONDS_OF_12HOUR) {
                        re = re + fee_s.chatFee;
                    };
                    i = i + 1;
                };
                if (re > 0) {
                    let earn = (((re as u128) * 70 / 100) as u64);
                    auser.amount = auser.amount + earn;
                    auser.earn = auser.earn + earn;
                    //earn
                    fid_re(auser.fid, fee_s.invite_reward_fee_den, fee_s.invite_reward_fee_num, earn, false);
                };
            };
            //reset msg_hoder of sender
            *vec = vector::empty<u64>();
        };
    }

    // fid: u64,
    // spend: u64,
    // earn: u64,
    // users: vector<address>,
    // all: u64,
    // amount: u64,
    fun fid_re(fid: u64, den: u128, num: u128, amount: u64, s: bool) acquires FidStore
    {
        let f = borrow_global_mut<FidStore>(@dat3);
        if (simple_mapv1::contains_key(&f.data, &fid)) {
            let fr = simple_mapv1::borrow_mut(&mut f.data, &fid);
            let val = (((amount as u128) * den / num) as u64);
            if (s) {
                fr.spend = fr.spend + val;
            }else {
                fr.earn = fr.earn + val;
            };
            fr.all = fr.all + val;
            fr.amount = fr.amount + val;
        };
    }

    public entry fun claim_reward(account: &signer, amount: u64) acquires UsersReward
    {
        let user_address = signer::address_of(account);
        assert!(exists<Member>(user_address), error::not_found(NO_USER));
        let user_r = borrow_global_mut<UsersReward>(@dat3);
        if (simple_mapv1::contains_key(&user_r.data, &user_address)) {
            let your = simple_mapv1::borrow_mut(&mut user_r.data, &user_address);
            assert!(amount < your.reward, error::out_of_range(EINSUFFICIENT_BALANCE));

            if (coin::is_account_registered<DAT3>(user_address)) {
                coin::register<DAT3>(account)
            };
            dat3_pool::withdraw_reward(user_address, amount);
            your.reward = your.reward - amount;
            your.claim = your.claim + amount;
        };
    }

    public entry fun claim_invite_reward(account: &signer, fid: u64) acquires FidStore
    {
        let addr = signer::address_of(account);
        assert!(exists<Member>(addr), error::not_found(NO_USER));
        let f_s = borrow_global_mut<FidStore>(@dat3);
        assert!(simple_mapv1::contains_key(&f_s.data, &fid), error::not_found(NOT_FOUND));
        let fid_r = simple_mapv1::borrow_mut(&mut f_s.data, &fid);

        if (addr == @dat3 && fid_r.fid == 999999999999999u64) {
            dat3_pool::withdraw(addr, fid_r.amount);
            fid_r.amount = 0;
        }else {
            let token_id = token::create_token_id_raw(
                @dat3_nft,
                fid_r.collection,
                fid_r.token,
                0
            );
            if (token::balance_of(addr, token_id) > 0) {
                dat3_pool::withdraw(addr, fid_r.amount);
                fid_r.amount = 0;
            };
        };
    }


    #[view]
    public fun assets(addr: address): (u64, u64, u64, u64, u64, u64, u64, u64)
    acquires Member, UsersReward
    {
        let _uid = 0u64;
        let _fid = 0u64;
        let _mFee = 0u64;
        let _amount = 0u64;
        if (exists<Member>(addr)) {
            let user = borrow_global<Member>(addr) ;
            _uid = user.uid;
            _fid = user.fid;
            _uid = user.mFee;
            _amount = user.amount;
        } ;

        let user_r = borrow_global<UsersReward>(@dat3);
        let _reward: u64 = 0;
        let _claim: u64 = 0;
        if (simple_mapv1::contains_key(&user_r.data, &addr)) {
            let your_reward = simple_mapv1::borrow(&user_r.data, &addr);
            _reward = your_reward.reward;
            _claim = your_reward.claim
        }else {
            _reward = 0;
            _claim = 0;
        };
        let _apt = 0u64;
        let dat3 = 0u64;
        if (coin::is_account_registered<0x1::aptos_coin::AptosCoin>(addr)) {
            _apt = coin::balance<0x1::aptos_coin::AptosCoin>(addr)
        };
        if (coin::is_account_registered<DAT3>(addr)) {
            dat3 = coin::balance<DAT3>(addr)
        } ;
        (_uid, _fid, _mFee, _apt, dat3, _amount, _reward, _claim)
    }

    #[view]
    public fun reward_recode(addr: address): (u64, u64, vector<u64>,vector<u64>, )
    acquires Member, UsersReward
    {
        let _earn = 0u64;
        let _dat3=0u64;
        let _every_reward_time= vector::empty<u64>();
        let _every_reward= vector::empty<u64>();
        if (exists<Member>(addr)) {
            let user = borrow_global<Member>(addr) ;
            _earn = user.earn;
            let ueer_r=borrow_global<UsersReward>(@dat3);
            if(simple_mapv1::contains_key(&ueer_r.data, &addr)){
               let r= simple_mapv1::borrow(&ueer_r.data, &addr);
                _dat3= r.claim+r.claim;
                _every_reward_time= r.every_reward_time;
                _every_reward= r.every_reward;
            };
        } ;
        (_earn, _dat3, _every_reward_time, _every_reward)
    }

    fun assert_room_state(addr: address): u8 acquires RoomState
    {
        let data = borrow_global<RoomState>(@dat3) ;
        *simple_mapv1::borrow(&data.data, &addr)
    }

    fun room_state(addr: address, state: u8) acquires RoomState
    {
        let data = borrow_global_mut<RoomState>(@dat3) ;
        if (!simple_mapv1::contains_key(&data.data, &addr)) {
            simple_mapv1::add(&mut data.data, addr, state);
        }else {
            let s = simple_mapv1::borrow_mut(&mut data.data, &addr);
            *s = state;
        };
    }

    fun room_state_change(addr: address, state: u8) acquires RoomState
    {
        let data = borrow_global_mut<RoomState>(@dat3) ;
        let s = simple_mapv1::borrow_mut(&mut data.data, &addr);
        *s = state;
    }

    // 1. A requester can initiate a payment stream session for a video call.
    public entry fun create_rome(requester: &signer, receiver: address
    ) acquires Room, Member, FeeStore, RoomState
    {
        let requester_addr = signer::address_of(requester);
        //check user
        assert!(requester_addr != receiver, error::invalid_argument(INVALID_RECEIVER));
        assert!(exists<Member>(requester_addr), error::not_found(NO_USER));
        assert!(exists<Member>(receiver), error::not_found(NO_RECEIVER_USER));
        //get req_member
        let req_member = borrow_global<Member>(requester_addr) ;
        //get fee
        let fee_store = borrow_global<FeeStore>(receiver) ;
        let fee = simple_mapv1::borrow(&fee_store.mFee, &req_member.mFee);
        //Deposit funds to rome extract amount
        if (exists<Room>(requester_addr)) {
            let session = borrow_global_mut<Room>(requester_addr);
            assert!(session.done, error::invalid_state(ALREADY_HAS_OPEN_SESSION));

            // Overwrite the finished session
            session.started_at = 0;
            session.finished_at = 0;
            session.minute_rate = *fee;
            session.receiver = receiver;
            session.deposit = 0;
            session.done = false;
            session.minute = 0;
            session.addr = requester_addr;
        } else {
            move_to(requester, Room {
                started_at: 0,
                finished_at: 0,
                minute_rate: *fee,
                receiver,
                deposit: 0,
                minute: 0,
                done: false,
                addr: requester_addr,
            })
        };
        room_state(requester_addr, 1);
        room_state(receiver, 0);
    }

    // 2. The receiver can join the session through the video call link
    public entry fun join_room(receiver: &signer, requester: address, join: bool) acquires Room, RoomState, Member
    {
        let receiver_addr = signer::address_of(receiver);
        assert!(exists<Member>(receiver_addr), error::not_found(NO_USER));
        assert!(exists<Member>(requester), error::not_found(NO_USER));
        assert!(exists<Room>(requester), error::invalid_state(INVALID_REQUESTER));
        let req_session = borrow_global_mut<Room>(requester);
        //check receiver
        assert!(
            (req_session.receiver == receiver_addr) && req_session.addr == requester,
            error::invalid_state(INVALID_RECEIVER)
        );
        if (join) {
            //check req state
            assert!(req_session.started_at == 0, error::invalid_state(WHO_HAS_ALREADY_JOINED));
            //check rec state
            assert!(assert_room_state(receiver_addr) == 0, error::invalid_state(YOU_HAS_ALREADY_JOINED));
            let req_user = borrow_global_mut<Member>(requester);
            //check req_user balance
            assert!(req_user.amount >= req_session.minute_rate, EINSUFFICIENT_BALANCE);
            req_user.amount = req_user.amount - req_session.minute_rate;
            req_session.started_at = timestamp::now_seconds();
            //first minute
            req_session.minute = 1;
            //Deduction in the first minute
            req_session.deposit = req_session.deposit + req_session.minute_rate;
            room_state(receiver_addr, 2);
        }else {
            req_session.done = true;
            room_state(requester, 0);
        };
    }

    public entry fun one_minute(requester: &signer) acquires Room, RoomState, Member, FeeStore, FidStore
    {
        let requester_addr = signer::address_of(requester);
        assert!(exists<Member>(requester_addr), error::not_found(NO_USER));
        assert!(exists<Room>(requester_addr), error::invalid_state(INVALID_REQUESTER));
        let req_session = borrow_global_mut<Room>(requester_addr);
        //check done
        assert!(!req_session.done, error::invalid_state(INVALID_ROOM_STATE));
        //check req state
        assert!(req_session.started_at > 0, error::invalid_state(INVALID_ROOM_STATE));
        //check rec state
        assert!(assert_room_state(requester_addr) == 0, error::invalid_state(INVALID_ROOM_STATE));
        let req_user = borrow_global_mut<Member>(requester_addr);
        //check req_user balance
        assert!(req_user.amount >= req_session.minute_rate, error::aborted(EINSUFFICIENT_BALANCE));
        req_user.amount = req_user.amount - req_session.minute_rate;

        //first minute
        req_session.minute = req_session.minute + 1;
        //Deduction in the first minute
        req_session.deposit = req_session.deposit + req_session.minute_rate;

        let fee_s = borrow_global<FeeStore>(@dat3);
        fid_re(req_user.fid, fee_s.invite_reward_fee_den, fee_s.invite_reward_fee_num, req_session.minute_rate, true);
    }

    //3. Upon closing of the session, send payment to the receiver, and refund any remaining funds to the requester
    public entry fun close_room(account: &signer, requester: address, receiver: address)
    acquires Room, Member, RoomState, UsersTotalConsumption, FeeStore, FidStore
    {
        let account_addr = signer::address_of(account);
        assert!(exists<Member>(receiver), error::not_found(NO_USER));
        assert!(exists<Member>(receiver), error::not_found(NO_USER));
        assert!(exists<Room>(requester), error::invalid_state(INVALID_RECEIVER));
        let req = borrow_global_mut<Room>(receiver);
        //check done
        assert!(!req.done, error::invalid_state(INVALID_ROOM_STATE));
        //check receiver
        assert!(
            (req.receiver == receiver) && (req.addr == requester) && (account_addr == req.receiver || account_addr == req.addr),
            error::invalid_state(INVALID_RECEIVER)
        );
        //check time
        assert!(req.started_at > 0 && req.finished_at == 0, error::invalid_state(INVALID_RECEIVER));
        let now_s = timestamp::now_seconds();
        //to return req.deposit
        req.finished_at = now_s;
        req.done = true;
        let to_rec = req.deposit;
        req.deposit == 0;
        // UsersTotal
        let total = borrow_global_mut<UsersTotalConsumption>(@dat3);
        let map = total.data;
        let your = simple_mapv1::borrow_mut(&mut map, &requester);
        *your = *your + to_rec;
        //to rec
        let rec_user = borrow_global_mut<Member>(receiver);
        rec_user.amount = rec_user.amount + (((to_rec * 70 as u128) / (100u128)) as u64);
        let fee_s = borrow_global<FeeStore>(@dat3);
        rec_user.earn = rec_user.earn + (((to_rec * 70 as u128) / (100u128)) as u64);
        //earn
        fid_re(
            rec_user.fid,
            fee_s.invite_reward_fee_den,
            fee_s.invite_reward_fee_num,
            (((to_rec * 70 as u128) / (100u128)) as u64),
            false
        );
        //change state
        room_state_change(requester, 0);
        room_state_change(receiver, 0);
    }

    #[view]
    public fun remaining_time(requester: address): (address, address, u64, u64, u64, u64, u64, bool)
    acquires Room
    {
        assert!(exists<Room>(requester), error::not_found(NO_USER));
        let room = borrow_global<Room>(requester);
        (room.addr, room.receiver, room.started_at, room.finished_at, room.minute_rate, room.minute, room.deposit, room.done)
    }
}