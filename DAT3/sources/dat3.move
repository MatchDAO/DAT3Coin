module publisher::dat3 {

    use aptos_framework::coin;
    use std::string;
    use aptos_framework::coin::{BurnCapability, FreezeCapability, MintCapability};
    use std::signer;

    struct DAT3 has key, store {}

    struct HodeCap has key {
        burnCap: BurnCapability<DAT3>,
        freezeCap: FreezeCapability<DAT3>,
        mintCap: MintCapability<DAT3>,
    }

    // public fun initialize<CoinType>(
    //     account: &signer,
    //     name: string::String,
    //     symbol: string::String,
    //     decimals: u8,
    //     monitor_supply: bool,
    // ): (BurnCapability<CoinType>, FreezeCapability<CoinType>, MintCapability<CoinType>) {
    //     initialize_internal(account, name, symbol, decimals, monitor_supply, false) }
    public entry fun init(sender: &signer) {
        let (burnCap, freezeCap, mintCap) =
            coin::initialize<DAT3>(sender,
                string::utf8(b"DAT3"),
                string::utf8(b"DAT3"),
                6u8, true);
        move_to(sender, HodeCap { burnCap, freezeCap, mintCap })
    }

    public entry fun mint_me(sender: &signer, amount: u64) acquires HodeCap {
        let cap = borrow_global<HodeCap>(@publisher);
        let mint_coin = coin::mint(amount, &cap.mintCap);
        let owner = signer::address_of(sender);
        if (!coin::is_account_registered<DAT3>(owner)) {
            coin::register<DAT3>(sender);
        };
        coin::deposit(owner, mint_coin)
    }
}
