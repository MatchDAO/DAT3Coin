module dat3::dat3_coin {
    use std::signer;
    use std::string;

    use aptos_std::math64;
    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};




    struct DAT3 has key {}

    struct HodeCap has key {
        burnCap: BurnCapability<DAT3>,
        freezeCap: FreezeCapability<DAT3>,
        mintCap: MintCapability<DAT3>,
    }

    const ERR_NOT_ENOUGH_PERMISSIONS: u64 = 1000;
    const INVALID_ARGUMENT: u64 = 106;

    public entry fun init(owner: &signer) {
        assert!(signer::address_of(owner) == @dat3, ERR_NOT_ENOUGH_PERMISSIONS);
        let (burnCap, freezeCap, mintCap) =
            coin::initialize<DAT3>(owner,
                string::utf8(b"DAT3 Coin"),
                string::utf8(b"DAT3"),
                6u8, true);
        let mint_coin = coin::mint(math64::pow(10, (coin::decimals<DAT3>() as u64)) * 7200, &mintCap);
        move_to(owner, HodeCap { burnCap, freezeCap, mintCap });
        coin::register<DAT3>(owner);
        coin::deposit(signer::address_of(owner), mint_coin);
    }

    public entry fun register(sender: &signer) {
        if (!coin::is_account_registered<DAT3>(signer::address_of(sender))) {
            coin::register<DAT3>(sender)
        };
    }

    public entry fun mint_to(owner: &signer, amount: u64, to: address) acquires HodeCap {
        assert!(signer::address_of(owner) == @dat3, ERR_NOT_ENOUGH_PERMISSIONS);
        let cap = borrow_global<HodeCap>(@dat3);
        let mint_coin = coin::mint(amount, &cap.mintCap);
        coin::deposit(to, mint_coin)
    }


    //mint_to
    public entry fun mint_once(owner: &signer, amount: u64, to: address) acquires HodeCap {
        assert!(signer::address_of(owner) == @dat3, INVALID_ARGUMENT);
        assert!(
            amount <= math64::pow(10, (coin::decimals<DAT3>() as u64)) * 7200 || amount == 0,
            ERR_NOT_ENOUGH_PERMISSIONS
        );
        let cap = borrow_global<HodeCap>(@dat3);
        let mint_coin = coin::mint(amount, &cap.mintCap);
        //to RewardPool 0.7
        //dat3_pool::deposit_reward();
        let user_address = signer::address_of(owner);
        coin::deposit(user_address, coin::extract(&mut mint_coin, (((amount as u128) * 70 / 100) as u64)));
        coin::deposit(to, mint_coin);
    }


    #[test_only]
    use aptos_framework::coin::is_account_registered;
    #[test_only]
    use aptos_std::debug;
    #[test_only]
    use aptos_framework::aptos_account::{create_account};



    #[test(dat3 = @dat3, to = @dat3_admin)]
    fun dat3_coin_init(
        dat3: &signer, to: &signer
    ) {
        let addr = signer::address_of(dat3);
        let to_addr = signer::address_of(to);
        create_account(addr);
        create_account(to_addr);
        init(dat3);
        coin::register<DAT3>(dat3);
        debug::print(&is_account_registered<DAT3>(addr));
        let balance = coin::balance<DAT3>(addr);
        debug::print(&balance);
        coin::register<DAT3>(to);
        coin::transfer<DAT3>(dat3, to_addr, 10001111);

        debug::print(&coin::balance<DAT3>(addr));
        debug::print(&coin::balance<DAT3>(to_addr));

    }
}
