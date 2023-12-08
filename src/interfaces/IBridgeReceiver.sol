interface IBridgeReceiver {
    function onFundsReceivedCallback(
        address token,
        uint amount,
        uint left
    ) external;
}
