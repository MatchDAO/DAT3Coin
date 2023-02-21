module publisher::dat3_coin {
    use std::signer;
    use std::string;

    use aptos_std::math64;
    use aptos_framework::coin::{Self, BurnCapability, FreezeCapability, MintCapability};

    use publisher::dat3_pool;

    struct DAT3 has key, store {}

    struct HodeCap has key {
        burnCap: BurnCapability<DAT3>,
        freezeCap: FreezeCapability<DAT3>,
        mintCap: MintCapability<DAT3>,
    }

    const ERR_NOT_ENOUGH_PERMISSIONS: u64 = 1000;
    const INVALID_ARGUMENT: u64 = 106;

    public entry fun init(sender: &signer) {
        assert!(signer::address_of(sender) == @publisher, ERR_NOT_ENOUGH_PERMISSIONS);
        let (burnCap, freezeCap, mintCap) =
            coin::initialize<DAT3>(sender,
                string::utf8(b"DAT3 Coin"),
                string::utf8(b"DAT3"),
                6u8, true);
        move_to(sender, HodeCap { burnCap, freezeCap, mintCap })
    }

    #[test_only]
    public entry fun mint_to(sender: &signer, amount: u64, to: address) acquires HodeCap {
        assert!(signer::address_of(sender) == @publisher, ERR_NOT_ENOUGH_PERMISSIONS);
        let cap = borrow_global<HodeCap>(@publisher);
        let mint_coin = coin::mint(amount, &cap.mintCap);
        coin::deposit(to, mint_coin)
    }


    //mint_to
    public entry fun mint_once(sender: &signer, amount: u64, to: address) acquires HodeCap {
        assert!(signer::address_of(sender) == @publisher, INVALID_ARGUMENT);
        assert!(
            amount <= (math64::pow(10, coin::decimals<DAT3>() as u64)) * 7200 || amount == 0,
            ERR_NOT_ENOUGH_PERMISSIONS
        );
        let cap = borrow_global<HodeCap>(@publisher);
        let mint_coin = coin::mint(amount, &cap.mintCap);
        //to RewardPool 0.7
        dat3_pool::deposit_reward(coin::extract(&mut mint_coin, ((amount as u128) * 70 / 100 as u64)));
        coin::deposit(to, mint_coin)

    }
}
