#!/bin/bash
#deploy script
# Deploy step 1 :publish DAT3CoinBoot
# Deploy step 2 :compile veDAT3Coin
# Deploy step 3 :run dat3::dat3_coin_boot::initializeWithResourceAccount()
# Deploy step 4 :publish DAT3CoinBoot
# Deploy step 2 :init
# Deploy step 2 :compile veDAT3Coin
# 0K ,The goal is to get the deployer's signature,
DAT3='0xaedd8a8933ba1fba08b9eff70e684ea11105438e5e5912ff9f53a0f409572933'
PROFILE="devnet"
echo "dat3:' $DAT3'"
DAT3_PATH=`pwd `
COIN_PATH="$DAT3_PATH/veDAT3Coin"
BOOT_PATH="$DAT3_PATH/DAT3CoinBoot"
DAT3Pool="$DAT3_PATH/DAT3Pool"

cd $BOOT_PATH
echo " step 1 :bigin compile&publish boot :  -->`pwd`"

echo `aptos move compile --package-dir "$BOOT_PATH" `

echo "aptos move publish -->  $BOOT_PATH  "
echo `aptos move publish --assume-yes --package-dir "$BOOT_PATH" `
echo "1-------------------------------------------------------------------------------------------"
cd $COIN_PATH
echo " step 2 :bigin compile veDAT3Coin : -->`pwd`"
echo "`ls`"
echo "aptos move compile --> $COIN_PATH "
echo `aptos move compile --save-metadata --package-dir  $COIN_PATH`
echo""

#hexdump -ve '1/1 "%.2x"' build/veDAT3Coin/package-metadata.bcs > meta.hex
#hexdump -ve '1/1 "%.2x"' build/veDAT3Coin/bytecode_modules/vedat3_coin.mv > coin.hex
#xxd -ps -c10000000 build/veDAT3Coin/package-metadata.bcs > meta.hex
#xxd -ps -c10000000 build/veDAT3Coin/bytecode_modules/vedat3_coin.mv > coin.hex
META=`xxd  -ps -c10000000  build/veDAT3Coin/package-metadata.bcs`
echo""
CODE=`xxd  -ps -c10000000  build/veDAT3Coin/bytecode_modules/vedat3_coin.mv`
echo "mata: $META"
echo "code: $CODE"

sleep 3 #
echo "2-------------------------------------------------------------------------------------------"
echo " step 3 :run dat3::dat3_coin_boot::initializeWithResourceAccount() "
echo " begin"
echo "$DAT3::dat3_coin_boot::initializeWithResourceAccount --args hex:$META  hex:$CODE"
echo""
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_coin_boot::initializeWithResourceAccount --args hex:"$META" hex:"$CODE" string:"dat3"`
sleep 2
echo""
cd $DAT3Pool
echo "aptos move compile -->  $DAT3Pool --bytecode-version 6 "
echo `aptos move compile --save-metadata --package-dir  $DAT3Pool --bytecode-version 6`
echo""
sleep 5
echo "aptos move publish --> $DAT3Pool --bytecode-version 6 "
echo `aptos move publish --assume-yes --package-dir  $DAT3Pool --bytecode-version 6 `
echo""
sleep 5
echo "dat3_manager::init_dat3_coin"
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_manager::init_dat3_coin`
echo""
#echo "dat3_stake::init"
#echo `aptos move run   --assume-yes --function-id $DAT3::dat3_stake::init`
echo""
sleep 3
echo " dat3_pool::init_pool "
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_pool::init_pool `
echo""
sleep 2
echo " dat3_pool_routel::init"
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_pool_routel::init`
echo""
sleep 2
echo " dat3_pool_routel::change_sys_fid --args u64:999999999999999  bool:false"
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_pool_routel::change_sys_fid --args u64:999999999999999  bool:false string:"t1" string:"c1" `
sleep 2
echo""
echo "dat3_pool_routel::user_init"
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_pool_routel::user_init   --args u64:999999999999999  u64:13 `
sleep 2