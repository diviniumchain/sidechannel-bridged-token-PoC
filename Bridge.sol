pragma solidity 0.5.3;

import 'openzeppelin-solidity/ownership/Ownable.sol';
import 'openzeppelin-solidity/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/token/ERC20/ERC20Detailed.sol';

interface Bridge {
    function relayMessage(bytes calldata data, address sender, address recipient) external;
}

contract BridgedToken is ERC20, ERC20Detailed, Ownable {
    Bridge private bridge;
    address private otherToken;

    constructor (address _owner, address _bridge, string memory _symbol, string memory _name, uint8 _decimals, uint _initialSupply, bool locked)
        public
        Ownable()
        ERC20Detailed(_name, _symbol, _decimals) {
            bridge = Bridge(_bridge);
            _transferOwnership(_owner);
            _mint(_owner, _initialSupply);
            if (locked) {
                _transfer(_owner, address(bridge), _initialSupply);
            }
        }

    function setOtherToken(address _other) public onlyOwner {
        otherToken = _other;
    }

    function lock(uint _amount) public {
        _transfer(msg.sender, address(bridge), _amount);
        bridge.relayMessage(abi.encodeWithSignature("unlock(address, uint256)", msg.sender, _amount), msg.sender, otherToken);
    }

    function unlock(address _account, uint _amount) public {
        require(msg.sender == address(bridge));
        _transfer(address(bridge), _account, _amount);
    }
}

contract BridgeMain is Ownable, Bridge {
    struct MessageStore {
        address _from; 
        address _to; 
        bytes data;
        uint votes;
    }
    
    uint oraclesLength = 0;
    mapping (address => bool) oracles;
    mapping (address => bool) contracts;
    mapping (bytes32 => MessageStore) messages;
    
    event Message(bytes data, address sender, address recipient);
    
    function relayMessage(bytes memory data, address sender, address recipient) public {
        require(contracts[msg.sender]);
        emit Message(data, sender, recipient);
    }
    
    function acceptMessage(address _from, address _to, bytes memory data) public {
        require(oracles[msg.sender]);
        bytes32 messageId = keccak256(abi.encodePacked(_from, _to, data));
        if (messages[messageId].votes == 0) {
            messages[messageId] = MessageStore(_from, _to, data, 0);
        }
        messages[messageId].votes += 1;
        
        if (messages[messageId].votes > oraclesLength / 2) {
            _to.call(data);
        }
    }
    
    function addOracle(address oracle) public onlyOwner {
        require(!oracles[oracle]);
        oracles[oracle] = true;
        oraclesLength += 1;
    }
    
    function addContract(address _contract) public onlyOwner {
        require(!contracts[_contract]);
        contracts[_contract] = true;
    }
}