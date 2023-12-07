interface IBridge {
    function deposit(
        address receiver,
        address token,
        uint256 _amount
    ) external payable;

    function withdraw(address token, uint256 _amount) external;

    function getFee(
        address token,
        uint256 _amount
    ) external returns (address, uint256);
}
