module dat3::dat3_manager {
    use std::signer;
    use std::string::{Self, String, utf8};

    use aptos_framework::account;
    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};
    use aptos_framework::event;
    use aptos_framework::timestamp::{Self, now_seconds};

    use dat3::dat3_coin::DAT3;

    #[test_only]
    use aptos_std::debug;
    #[test_only]
    use aptos_std::math64;
    #[test_only]
    use aptos_framework::aptos_account::create_account;
    #[test_only]
    use aptos_framework::coin::is_account_registered;
    #[test_only]
    use dat3::dat3_pool;
    use aptos_std::math128;
    use std::error;
    #[test_only]
    use dat3::dat3_pool_routel;
    use aptos_framework::account::{ SignerCapability};
    use dat3::simple_mapv1::SimpleMapV1;
    use aptos_token::token::{TokenMutabilityConfig, create_collection, create_token_mutability_config, create_tokendata, TokenId};
    use dat3::simple_mapv1;
    use std::vector;
    use aptos_token::token;
    #[test_only]
    use aptos_token::token::{check_collection_exists};
    #[test_only]
    use dat3::dat3_stake;

    struct HodeCap has key {
        burnCap: BurnCapability<DAT3>,
        freezeCap: FreezeCapability<DAT3>,
        mintCap: MintCapability<DAT3>,
    }

    /// genesis info
    struct GenesisInfo has key, store {
        /// seconds
        genesis_time: u64,
        /// withdraw bank event
        withdraw_event: event::EventHandle<WithdrawBankEvent>
    }

    struct MintTime has key, store {
        /// seconds
        time: u64,
        supplyAmount: u64,
    }

    struct WithdrawBankEvent has drop, store {
        /// to address
        to: address,
        /// withdraw amount
        amount: u64,
        /// coin type
        bank_name: String,
    }

    struct Collections has key {
        data: SimpleMapV1<String, CollectionConfig>
    }

    struct CollectionSin has key {
        sinCap: SignerCapability,
    }

    struct CollectionConfig has key, store {
        collection_name: String,
        collection_description: String,
        collection_maximum: u64,
        collection_uri: String,
        collection_mutate_config: vector<bool>,
        // this is base name, when minting, we will generate the actual token name as `token_name_base: sequence number`
        token_name_base: String,
        token_counter: u64,
        royalty_payee_address: address,
        token_description: String,
        token_maximum: u64,
        token_mutate_config: TokenMutabilityConfig,
        royalty_points_den: u64,
        royalty_points_num: u64,
        tokens: SimpleMapV1<String, TokenId>,
    }


    /// 100 million
    const MAX_SUPPLY_AMOUNT: u64 = 5256000 ;
    //365
    const SECONDS_OF_YEAR: u128 = 31536000 ;

    const TOTAL_EMISSION: u128 = 7200;
    //0.7
    const TALK_EMISSION: u128 = 5040;
    //0.1
    const ACTIVE_EMISSION: u128 = 720;
    //0.1
    const STAKE_EMISSION: u128 = 720;
    //0.1
    const INVESTER_EMISSION: u128 = 720;

    const PERMISSION_DENIED: u64 = 1000;
    const SUPPLY_OUT_OF_RANGE: u64 = 1001;

    const EINSUFFICIENT_BALANCE: u64 = 107u64;
    const NO_USER: u64 = 108u64;
    const NO_TO_USER: u64 = 108u64;
    const NOT_FOUND: u64 = 110u64;
    const ALREADY_EXISTS: u64 = 111u64;
    const OUT_OF_RANGE: u64 = 112;
    const INVALID_ARGUMENT: u64 = 113;
    const ASSERT_MINT_ERR: u64 = 114;


    public entry fun new_collection(admin: &signer,
                                    collection_name: String,
                                    collection_description: String,
                                    collection_maximum: u64,
                                    collection_uri: String,
                                    collection_mutate_config: vector<bool>,
                                    token_mutate_config: vector<bool>,
                                    // this is base name, when minting, we will generate the actual token name as `token_name_base: sequence number`
                                    token_name_base: String,
                                    royalty_payee_address: address,
                                    token_description: String,
                                    token_maximum: u64,
                                    royalty_points_den: u64,
                                    royalty_points_num: u64, ) acquires CollectionSin, Collections
    {
        let addr = signer::address_of(admin);
        if (!exists<CollectionSin>(@dat3_nft)) {
            let (resourceSigner, sinCap) = account::create_resource_account(admin, b"dat3_nft");
            move_to(&resourceSigner, CollectionSin { sinCap });
        };
        let sig = account::create_signer_with_capability(&borrow_global<CollectionSin>(@dat3_nft).sinCap);
        if (!exists<Collections>(addr)) {
            move_to(admin, Collections { data: simple_mapv1::create<String, CollectionConfig>() });
        };
        let coll_map = borrow_global_mut<Collections>(addr);
        if (simple_mapv1::contains_key(&coll_map.data, &collection_name)) {
            let config = simple_mapv1::borrow_mut(&mut coll_map.data, &collection_name);
            config.royalty_payee_address = royalty_payee_address;
            config.token_description = token_description;
            config.token_maximum = token_maximum;
            config.royalty_points_num = royalty_points_num;
        }else {
            simple_mapv1::add(&mut coll_map.data, collection_name, CollectionConfig {
                collection_name,
                collection_description,
                collection_maximum,
                collection_uri,
                collection_mutate_config,
                // this is base name, when minting, we will generate the actual token name as `token_name_base: sequence number`
                token_name_base,
                token_counter: 0,
                royalty_payee_address,
                token_description,
                royalty_points_den,
                token_maximum,
                token_mutate_config: create_token_mutability_config(&token_mutate_config),
                royalty_points_num,
                tokens: simple_mapv1::create<String, TokenId>(),
            })
        };
        create_collection(
            &sig,
            collection_name,
            collection_description,
            collection_uri,
            collection_maximum,
            collection_mutate_config
        );
    }

    public entry fun add_tokens(admin: &signer, collection_name: String, names: vector<String>)
    //: vector<TokenId>
    acquires Collections, CollectionSin
    {
        //let tids = vector::empty<TokenId>();
        let addr = signer::address_of(admin);
        let coll_s = borrow_global_mut<Collections>(addr);
        assert!(simple_mapv1::contains_key(&coll_s.data, &collection_name), error::not_found(NOT_FOUND));
        let cnf = simple_mapv1::borrow_mut(&mut coll_s.data, &collection_name);
        let sig = account::create_signer_with_capability(&borrow_global<CollectionSin>(@dat3_nft).sinCap);
        let len = vector::length(&names);
        let uri = string::utf8(
            b"https://ipfs.io/ipfs/bafybeibinkuleaosibfnmbwmj54pm5zvbdod5upuiod2fhaehhuym4uofm/images/"
        );
        let property_keys = vector::empty<String>();
        vector::push_back(&mut property_keys, string::utf8(b"length"));
        let property_types = vector::empty<0x1::string::String>();
        vector::push_back(&mut property_types, string::utf8(b"0x1::string::String"));
        let png = string::utf8(b".png");
        let i = 0;
        while (i < len) {
            let name = vector::borrow(&names, i);
            if (simple_mapv1::contains_key(&cnf.tokens, name))
                {
                    i = i + 1;
                    continue
                };
            let token_uri = uri ;
            string::append(&mut token_uri, *name);
            string::append(&mut token_uri, png);
            let property_values = vector::empty<vector<u8>>();
            let value = string::bytes(&u64_to_string(string::length(name)));
            vector::push_back(&mut property_values, *value);

            let token_name = cnf.token_name_base;
            string::append(&mut token_name, *name);

            let token_data_id = create_tokendata(
                &sig,
                cnf.collection_name,
                token_name,
                cnf.token_description,
                cnf.token_maximum,
                token_uri,
                cnf.royalty_payee_address,
                cnf.royalty_points_den,
                cnf.royalty_points_num,
                cnf.token_mutate_config,
                property_keys,
                property_values,
                property_types,
            );
            let token_id = token::mint_token(&sig, token_data_id, 1);
            simple_mapv1::add(&mut cnf.tokens, *name, token_id);
            token::direct_transfer(&sig, admin, token_id, 1);

            //  vector::push_back(&mut tids, token_id);
        };
        // tids
    }


    public entry fun init_dat3_coin(owner: &signer) acquires HodeCap, MintTime, GenesisInfo
    {
        assert!(signer::address_of(owner) == @dat3, error::permission_denied(PERMISSION_DENIED));
        //only once
        assert!(!exists<GenesisInfo>(@dat3), error::already_exists(ALREADY_EXISTS));
        let (burnCap, freezeCap, mintCap) =
            coin::initialize<DAT3>(owner,
                string::utf8(b"DAT3 Coin"),
                string::utf8(b"DAT3"),
                6u8, true);
        move_to(owner, HodeCap {
            burnCap, freezeCap, mintCap
        });
        coin::register<DAT3>(owner);
        move_to(owner,
            MintTime {
                time: 0,
                supplyAmount: 0
            }
        );

        let time = timestamp::now_seconds();

        move_to(owner,
            GenesisInfo {
                genesis_time: time,
                withdraw_event: account::new_event_handle<WithdrawBankEvent>(owner)
            }
        );
        dat3::dat3_stake::init(owner, time);
        mint_to(owner, signer::address_of(owner));
    }


    //Make sure it's only once a day
    fun assert_mint_time(): bool acquires MintTime
    {
        let last = borrow_global_mut<MintTime>(@dat3);
        assert!(last.supplyAmount <= MAX_SUPPLY_AMOUNT, error::out_of_range(SUPPLY_OUT_OF_RANGE));
        if (last.time == 0) {
            //Genesis
            last.time = 1;
            return true
        }else if (last.time == 1) {
            //the first time
            last.time = now_seconds();
            return true
        }else if (now_seconds() - last.time >= 86399) {
            //timer to mint
            last.time = now_seconds();
            return true
        };
        return false
    }

    fun assert_mint_num(): u128 acquires MintTime, GenesisInfo
    {
        let last = borrow_global<MintTime>(@dat3);
        let gen = borrow_global<GenesisInfo>(@dat3);
        assert!(last.supplyAmount <= MAX_SUPPLY_AMOUNT, error::out_of_range(SUPPLY_OUT_OF_RANGE));
        let now = timestamp::now_seconds();
        let year = ((now - gen.genesis_time) as u128) / SECONDS_OF_YEAR ;
        let m = 1u128;
        let i = 0u128;
        while (i < year) {
            m = m * 2;
            i = i + 1;
        };
        let mint = TOTAL_EMISSION / m  ;
        return mint
    }

    public entry fun mint_to(owner: &signer, to: address) acquires HodeCap, MintTime, GenesisInfo
    {
        assert!(signer::address_of(owner) == @dat3, error::permission_denied(PERMISSION_DENIED));
        assert!(assert_mint_time(), ASSERT_MINT_ERR);
        let cap = borrow_global<HodeCap>(@dat3);

        let ds = math128::pow(10, ((coin::decimals<DAT3>()) as u128));
        let mint_num = assert_mint_num();
        assert!(mint_num > 0, error::aborted(ASSERT_MINT_ERR));
        let mint_amount = ds * mint_num;
        let mint_coins = coin::mint((mint_amount as u64), &cap.mintCap);
        dat3::dat3_pool::deposit_reward_coin(
            owner,
            coin::extract(&mut mint_coins, ((mint_amount * TALK_EMISSION / TOTAL_EMISSION) as u64))
        );
        dat3::dat3_pool::deposit_active_coin(
            owner,
            coin::extract(&mut mint_coins, ((mint_amount * ACTIVE_EMISSION / TOTAL_EMISSION) as u64))
        );
        dat3::dat3_stake::mint_pool(
            owner,
            coin::extract(&mut mint_coins, ((mint_amount * STAKE_EMISSION / TOTAL_EMISSION) as u64))
        );
        coin::deposit(to, mint_coins);
        let last = borrow_global_mut<MintTime>(@dat3);
        last.supplyAmount = (mint_amount as u64) + last.supplyAmount;
    }


    #[test(dat3 = @dat3, to = @dat3_admin, fw = @aptos_framework)]
    fun dat3_coin_init(dat3: &signer, to: &signer, fw: &signer) acquires HodeCap, MintTime, GenesisInfo
    {
        timestamp::set_time_has_started_for_testing(fw);
        //  timestamp::update_global_time_for_test(1651255555255555);
        let a = 61u128;
        let temp = ((a / 60u128) as u64);
        let temp1 = ((a % 60u128) as u64);
        if (temp1 > 0) {
            temp = temp + 1;
        };
        debug::print(&temp);
        debug::print(&math64::pow(10, 6));
        let addr = signer::address_of(dat3);
        let to_addr = signer::address_of(to);
        create_account(addr);
        create_account(to_addr);
        init_dat3_coin(dat3);
        dat3_pool::init_pool(dat3);
        coin::register<DAT3>(dat3);
        debug::print(&is_account_registered<DAT3>(addr));
        dat3_pool_routel::init(dat3);
        let ssssss=  dat3_pool_routel::change_sys_fid(dat3,999u64,
            false,string::utf8(b"t1"),string::utf8(b"c1"));

        dat3_pool_routel::user_init(dat3, 999,
            100 );
        // user: &signer, fid: u64, del: bool, token: String, collection: String
        dat3_pool_routel::change_sys_fid(dat3,100,false,string::utf8(b"t1"),string::utf8(b"c1"));
        let (v1,v2,v3,v4,v5,v6 )= dat3_pool_routel::fid_reward(100);
        // let (v1,v2,v3,v4,v5,v6,v7,v8)=dat3_pool_routel::assets(addr);
        debug::print(&v1);
        debug::print(&v2);
        debug::print(&v3);
        debug::print(&v4);
        debug::print(&v5);
        debug::print(&v6);
        // debug::print(&v7);
        // debug::print(&v8);


        // dat3_pool_routel::change_sys_fid(dat3, 123, false);
        // dat3_pool_routel::user_init(dat3, 123, 12);
        let time = borrow_global<GenesisInfo>(addr).genesis_time;
        //  let sss = dat3::dat3_stake::ggg();
        debug::print(&time);
        //  debug::print(&sss);
    }

    #[test(dat3 = @dat3, to = @dat3_admin, fw = @aptos_framework)]
    fun dat3_nft_init(
        dat3: &signer, to: &signer, fw: &signer
    ) acquires HodeCap, MintTime, GenesisInfo, CollectionSin, Collections
    {
        timestamp::set_time_has_started_for_testing(fw);
        //  timestamp::update_global_time_for_test(1651255555255555);
        let a = 61u128;
        let temp = ((a / 60u128) as u64);
        let temp1 = ((a % 60u128) as u64);
        if (temp1 > 0) {
            temp = temp + 1;
        };
        debug::print(&temp);
        debug::print(&math64::pow(10, 6));
        let addr = signer::address_of(dat3);
        let to_addr = signer::address_of(to);
        create_account(addr);
        create_account(to_addr);
        init_dat3_coin(dat3);
        dat3_pool::init_pool(dat3);
        coin::register<DAT3>(dat3);
        debug::print(&is_account_registered<DAT3>(addr));

        dat3_pool_routel::init(dat3);

        // dat3_pool_routel::change_sys_fid(dat3, 123, false);
        // dat3_pool_routel::user_init(dat3, 123, 12);

        let tb = vector::empty<bool>();
        vector::push_back(&mut tb, false);
        vector::push_back(&mut tb, false);
        vector::push_back(&mut tb, false);
        let tb1 = vector::empty<bool>();
        vector::push_back(&mut tb1, false);
        vector::push_back(&mut tb1, false);
        vector::push_back(&mut tb1, false);
        vector::push_back(&mut tb1, false);
        vector::push_back(&mut tb1, false);
        new_collection(dat3,
            string::utf8(b"name1"),
            string::utf8(b"ddd"),
            11, string::utf8(b"name1"),
            tb, tb1,
            string::utf8(b"name -->#"),
            @dat3,
            string::utf8(b"code #"),
            1, 1000, 50
        );
        let check_coll = check_collection_exists(@dat3_nft, string::utf8(b"name1"));
        debug::print(&check_coll);
        let names = vector::empty<String>();
        vector::push_back(&mut names, string::utf8(b"1"));
        vector::push_back(&mut names, string::utf8(b"1"));
        vector::push_back(&mut names, string::utf8(b"3"));
        vector::push_back(&mut names, string::utf8(b"4"));
        vector::push_back(&mut names, string::utf8(b"5"));
        vector::push_back(&mut names, string::utf8(b"6"));
        vector::push_back(&mut names, string::utf8(b"7"));

        add_tokens(dat3, string::utf8(b"name1"), names, );


        let token_id = token::create_token_id_raw(
            @dat3_nft,
            string::utf8(b"name1"),
            string::utf8(b"name -->#3"),
            0
        );
        //  let i = 0u64;
        // while (i < vector::length(&sss)) {
        //     debug::print( vector::borrow(&sss, i));
        //     i=i+1;
        // };
        debug::print(&token::balance_of(@dat3, token_id));

        debug::print(&token::balance_of(@dat3, token_id));
        debug::print(&token_id);

        let (addr, s1, s2, s3) = token::get_token_id_fields(&token_id);
        debug::print(&addr);
        debug::print(&s1);
        debug::print(&s2);
        debug::print(&s3);
        let td = token::get_tokendata_id(token_id);
        let s = token::get_tokendata_uri(@dat3_nft, td);
        debug::print(&s);
    }

    #[test(dat3 = @dat3, to = @dat3_admin, fw = @aptos_framework)]
    fun dat3_stake(dat3: &signer, to: &signer, fw: &signer) acquires HodeCap, MintTime, GenesisInfo
    {
        timestamp::set_time_has_started_for_testing(fw);
        timestamp::update_global_time_for_test(1651255555255555);
        let addr = signer::address_of(dat3);
        let to_addr = signer::address_of(to);
        create_account(addr);
        create_account(to_addr);
        init_dat3_coin(dat3);
        dat3_pool::init_pool(dat3);
        coin::register<DAT3>(dat3);
        debug::print(&is_account_registered<DAT3>(addr));
        // dat3_pool_routel::init(dat3);
        debug::print(&string::utf8(b"begin"));
        debug::print(&coin::balance<DAT3>(addr));
        dat3_stake::deposit(dat3, 100, 0);
        debug::print(&coin::balance<DAT3>(addr));
        dat3_stake::withdraw(dat3);
        debug::print(&coin::balance<DAT3>(addr));
        debug::print(&coin::balance<DAT3>(addr));
        // let (v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11) = dat3_stake::your_staking(to_addr);
        // debug::print(&string::utf8(b"begin"));
        // debug::print(&v1);
        // debug::print(&v2);
        // debug::print(&v3);
        // debug::print(&v4);
        // debug::print(&v5);
        // debug::print(&v6);
        // debug::print(&v7);
        // debug::print(&v8);
        // debug::print(&v9);
        // debug::print(&v10);
        // debug::print(&v11);
    }

    fun u64_to_string(value: u64): String
    {
        if (value == 0) {
            return utf8(b"0")
        };
        let buffer = vector::empty<u8>();
        while (value != 0) {
            vector::push_back(&mut buffer, ((48 + value % 10) as u8));
            value = value / 10;
        };
        vector::reverse(&mut buffer);
        utf8(buffer)
    }
}