#!/bin/bash
#deploy script
# Deploy step 1 :publish DAT3CoinBoot
# Deploy step 2 :compile veDAT3Coin
# Deploy step 3 :run dat3::dat3_coin_boot::initializeWithResourceAccount()
# Deploy step 4 :publish DAT3CoinBoot
# Deploy step 2 :init
# Deploy step 2 :compile veDAT3Coin
# 0K ,The goal is to get the deployer's signature,
DAT3='0xf1d6ae40b4e4f626bf258d24e0c36cdf6bf9498a686119db679e7a1dbe9a4ecb'
PROFILE="devnet"
echo "dat3:'0x$DAT3'" FUNCTION_RESOLUTION_FAILURE
DAT3_PATH=`pwd `
COIN_PATH="$DAT3_PATH/veDAT3Coin"
BOOT_PATH="$DAT3_PATH/DAT3CoinBoot"
DAT3Pool="$DAT3_PATH/DAT3Pool"

cd $BOOT_PATH
echo " step 1 :bigin compile&publish boot :  -->`pwd`"
echo "`ls`"
echo `aptos move compile --package-dir "$BOOT_PATH"`

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
echo "aptos move compile -->  $DAT3Pool "
echo `aptos move compile --save-metadata --package-dir  $DAT3Pool`
echo""
sleep 2
echo "aptos move publish --> $DAT3Pool"
echo `aptos move publish --assume-yes --package-dir  $DAT3Pool  `
echo""
sleep 2
echo "$DAT3::dat3_manager::init_dat3_coin"
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_manager::init_dat3_coin`
echo""
sleep 2
echo "$DAT3::dat3_pool::init_pool --type-args 0x1::aptos_coin::AptosCoin"
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_pool::init_pool --type-args "0x1::aptos_coin::AptosCoin" `
echo""
sleep 2
echo "$DAT3::dat3_pool_routel::init"
echo `aptos move run   --assume-yes --function-id $DAT3::dat3_pool_routel::init`
#sleep 2
#echo "$DAT3::dat3_pool_routel::user_init"
#echo `aptos move run   --assume-yes --function-id $DAT3::dat3_pool_routel::user_init --type-args "0x1::aptos_coin::AptosCoin" --args u64:12  u64:13 `
#sleep 2