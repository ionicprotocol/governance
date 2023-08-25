// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./interfaces/IBribe.sol";
import "./interfaces/IBribeFactory.sol";
import "./interfaces/IGauge.sol";
import "./interfaces/IGaugeFactory.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IMinter.sol";
import "./interfaces/IMarket.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IVoteEscrow.sol";
import "./VoterRolesAuthority.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract Voter is IVoter, OwnableUpgradeable, ReentrancyGuardUpgradeable {
  address public _ve; // the ve token that governs these contracts
  address internal base; // $ion token
  address public gaugeFactory; // gauge factory
  address[] public gaugeFactories; // array with all the gauge factories
  address public bribeFactory; // bribe factory (internal and external)
  VoterRolesAuthority public permissionRegistry; // registry to check accesses
  address[] public targets; // all markets/pools viable for incentives

  uint internal index; // gauge index
  uint internal constant TWO_WEEKS = 2 weeks;
  uint public voteDelay; // delay between votes in seconds
  uint public constant MAX_VOTE_DELAY = 10 days; // Max vote delay allowed

  mapping(address => uint) internal supplyIndex; // gauge    => index
  mapping(address => uint) public claimable; // gauge    => claimable $ion
  mapping(address => address) public gauges; // market/pool     => gauge
  mapping(address => uint) public gaugesDistributionTimestamp; // gauge    => last Distribution Time
  mapping(address => address) public targetForGauge; // gauge    => market/pool
  mapping(address => address) public internal_bribes; // gauge    => internal bribe (only fees)
  mapping(address => address) public external_bribes; // gauge    => external bribe (real bribes)
  mapping(uint => mapping(address => uint256)) public votes; // nft      => market/pool     => votes
  mapping(uint => address[]) public targetVote; // nft      => markets/pools
  mapping(uint => mapping(address => uint)) internal weightsPerEpoch; // timestamp => market/pool => weights
  mapping(uint => uint) internal totWeightsPerEpoch; // timestamp => total weights
  mapping(uint => uint) public usedWeights; // nft      => total voting weight of user
  mapping(uint => uint) public lastVoted; // nft      => timestamp of last vote
  mapping(address => bool) public isGauge; // gauge    => boolean [is a gauge?]
  mapping(address => bool) public isAlive; // gauge    => boolean [is the gauge alive?]
  mapping(address => bool) public isGaugeFactory; // g.factory=> boolean [the gauge factory exists?]
  address public minter;

  event PairGaugeCreated(
    address indexed gauge,
    address creator,
    address internal_bribe,
    address indexed external_bribe,
    address indexed market
  );
  event MarketGaugeCreated(
    address indexed gauge,
    address creator,
    address internal_bribe,
    address indexed external_bribe,
    address indexed target
  );
  event GaugeKilled(address indexed gauge);
  event GaugeRevived(address indexed gauge);
  event Voted(address indexed voter, uint tokenId, uint256 weight);
  event Abstained(uint tokenId, uint256 weight);
  event NotifyReward(address indexed sender, address indexed reward, uint amount);
  event DistributeReward(address indexed sender, address indexed gauge, uint amount);

  constructor() {
    _disableInitializers();
  }

  function reinitialize(address __ve) public reinitializer(2) {
    _ve = __ve;
  }

  function initialize(
    address __ve,
    address _gauges,
    address _bribes,
    address _minter,
    VoterRolesAuthority _permissionsRegistry
  ) public initializer {
    __Ownable_init();
    __ReentrancyGuard_init();

    _ve = __ve;
    base = IVoteEscrow(__ve).token();

    gaugeFactory = _gauges;
    gaugeFactories.push(_gauges);
    isGaugeFactory[_gauges] = true;

    bribeFactory = _bribes;
    minter = _minter;
    permissionRegistry = _permissionsRegistry;

    voteDelay = 0;
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    MODIFIERS
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

  modifier VoterAdmin() {
    require(
      msg.sender == owner() || permissionRegistry.canCall(msg.sender, address(this), msg.sig),
      "ERR: VOTER_ADMIN"
    );
    _;
  }

  modifier Governance() {
    require(isGovernor(), "ERR: GOVERNANCE");
    _;
  }

  function isGovernor() internal view returns (bool) {
    return msg.sender == owner() || permissionRegistry.canCall(msg.sender, address(this), msg.sig);
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    VoterAdmin
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

  /// @notice set vote delay in seconds
  function setVoteDelay(uint _delay) external VoterAdmin {
    require(_delay != voteDelay, "!same delay");
    require(_delay <= MAX_VOTE_DELAY, "!over max delay");
    voteDelay = _delay;
  }

  /// @notice Set a new Bribe Factory
  function setBribeFactory(address _bribeFactory) external VoterAdmin {
    bribeFactory = _bribeFactory;
  }

  /// @notice Set a new Gauge Factory
  function setGaugeFactory(address _gaugeFactory) external VoterAdmin {
    gaugeFactory = _gaugeFactory;
  }

  /// @notice Set a new PermissionRegistry
  function setPermissionsRegistry(VoterRolesAuthority _permissionRegistry) external VoterAdmin {
    permissionRegistry = _permissionRegistry;
  }

  /// @notice Set a new bribes for a given gauge
  function setNewBribes(address _gauge, address _internal, address _external) external VoterAdmin {
    require(isGauge[_gauge], "not a gauge");
    internal_bribes[_gauge] = _internal;
    external_bribes[_gauge] = _external;
  }

  /// @notice Set a new internal bribe for a given gauge
  function setInternalBribeFor(address _gauge, address _internal) external VoterAdmin {
    require(isGauge[_gauge], "not a gauge");
    internal_bribes[_gauge] = _internal;
  }

  /// @notice Set a new External bribe for a given gauge
  function setExternalBribeFor(address _gauge, address _external) external VoterAdmin {
    require(isGauge[_gauge], "not a gauge");
    external_bribes[_gauge] = _external;
  }

  /// @notice Increase gauge approvals if max is type(uint).max is reached    [very long run could happen]
  function increaseGaugeApprovals(address _gauge) external VoterAdmin {
    require(isGauge[_gauge], "not a gauge");
    IERC20(base).approve(_gauge, 0);
    IERC20(base).approve(_gauge, type(uint).max);
  }

  function addFactory(address _gaugeFactory) external VoterAdmin {
    require(_gaugeFactory != address(0), "addr 0");
    require(!isGaugeFactory[_gaugeFactory], "g.fact true");
    gaugeFactories.push(_gaugeFactory);
    isGaugeFactory[_gaugeFactory] = true;
  }

  function replaceFactory(address _gaugeFactory, uint256 _pos) external VoterAdmin {
    require(_gaugeFactory != address(0), "addr 0");
    require(isGaugeFactory[_gaugeFactory], "g.fact false");
    address oldGF = gaugeFactories[_pos];
    isGaugeFactory[oldGF] = false;
    gaugeFactories[_pos] = (_gaugeFactory);
    isGaugeFactory[_gaugeFactory] = true;
  }

  function removeFactory(uint256 _pos) external VoterAdmin {
    address oldGF = gaugeFactories[_pos];
    require(isGaugeFactory[oldGF], "g.fact false");
    gaugeFactories[_pos] = address(0);
    isGaugeFactory[oldGF] = false;
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    GOVERNANCE
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

  /// @notice Kill a malicious gauge
  /// @param  _gauge gauge to kill
  function killGauge(address _gauge) external Governance {
    require(isAlive[_gauge], "gauge already dead");
    isAlive[_gauge] = false;
    claimable[_gauge] = 0;
    emit GaugeKilled(_gauge);
  }

  /// @notice Revive a malicious gauge
  /// @param  _gauge gauge to revive
  function reviveGauge(address _gauge) external Governance {
    require(!isAlive[_gauge], "gauge already alive");
    require(isGauge[_gauge], "gauge killed totally");
    isAlive[_gauge] = true;
    supplyIndex[_gauge] = index;
    emit GaugeRevived(_gauge);
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    USER INTERACTION
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

  /// @notice Reset the votes of a given TokenID
  function reset(uint _tokenId) external nonReentrant {
    _voteDelay(_tokenId);
    require(IVoteEscrow(_ve).isApprovedOrOwner(msg.sender, _tokenId), "not owner or approved");
    _reset(_tokenId);
    IVoteEscrow(_ve).abstain(_tokenId);
    lastVoted[_tokenId] = _epochTimestamp() + 1;
  }

  function _reset(uint _tokenId) internal {
    address[] storage _targetVote = targetVote[_tokenId];
    uint _targetVoteCnt = _targetVote.length;
    uint256 _totalWeight = 0;
    uint256 _time = _epochTimestamp();

    for (uint i = 0; i < _targetVoteCnt; i++) {
      address _target = _targetVote[i];
      uint256 _votes = votes[_tokenId][_target];

      if (_votes != 0) {
        // if user last vote is < than epochTimestamp then votes are 0! IF not underflow occur
        if (lastVoted[_tokenId] > _epochTimestamp()) weightsPerEpoch[_time][_target] -= _votes;

        votes[_tokenId][_target] -= _votes;
        _totalWeight += _votes;

        emit Abstained(_tokenId, _votes);
      }
    }

    // if user last vote is < than epochTimestamp then _totalWeight is 0! IF not underflow occur
    if (lastVoted[_tokenId] < _epochTimestamp()) _totalWeight = 0;

    totWeightsPerEpoch[_time] -= _totalWeight;
    usedWeights[_tokenId] = 0;
    delete targetVote[_tokenId];
  }

  /// @notice Recast the saved votes of a given TokenID
  function poke(uint _tokenId) external nonReentrant {
    _voteDelay(_tokenId);
    require(IVoteEscrow(_ve).isApprovedOrOwner(msg.sender, _tokenId), "not owner or approved");
    address[] memory _targetVote = targetVote[_tokenId];
    uint _targetCnt = _targetVote.length;
    uint256[] memory _weights = new uint256[](_targetCnt);

    for (uint i = 0; i < _targetCnt; i++) {
      _weights[i] = votes[_tokenId][_targetVote[i]];
    }

    _vote(_tokenId, _targetVote, _weights);
    lastVoted[_tokenId] = _epochTimestamp() + 1;
  }

  /// @notice Vote for targets
  /// @param  _tokenId    veNFT tokenID used to vote
  /// @param  _targetVote   array of gauges target addresses
  /// @param  _weights    array of weights for each gauge target
  function vote(uint _tokenId, address[] calldata _targetVote, uint256[] calldata _weights) external nonReentrant {
    _voteDelay(_tokenId);
    require(IVoteEscrow(_ve).isApprovedOrOwner(msg.sender, _tokenId), "not owner or approved");
    require(_targetVote.length == _weights.length, "arr len");
    _vote(_tokenId, _targetVote, _weights);
    lastVoted[_tokenId] = _epochTimestamp() + 1;
  }

  function _vote(uint _tokenId, address[] memory _targetVote, uint256[] memory _weights) internal {
    _reset(_tokenId);
    uint _targetCnt = _targetVote.length;
    uint256 _weight = IVoteEscrow(_ve).balanceOfNFT(_tokenId);
    uint256 _totalVoteWeight = 0;
    uint256 _totalWeight = 0;
    uint256 _usedWeight = 0;
    uint256 _time = _epochTimestamp();

    for (uint i = 0; i < _targetCnt; i++) {
      _totalVoteWeight += _weights[i];
    }

    for (uint i = 0; i < _targetCnt; i++) {
      address _target = _targetVote[i];
      address _gauge = gauges[_target];

      if (isGauge[_gauge] && isAlive[_gauge]) {
        uint256 _targetWeight = (_weights[i] * _weight) / _totalVoteWeight;
        require(votes[_tokenId][_target] == 0, "already voted for target");
        require(_targetWeight != 0, "zero vote w");

        targetVote[_tokenId].push(_target);
        weightsPerEpoch[_time][_target] += _targetWeight;

        votes[_tokenId][_target] += _targetWeight;

        _usedWeight += _targetWeight;
        _totalWeight += _targetWeight;
        emit Voted(msg.sender, _tokenId, _targetWeight);
      }
    }
    if (_usedWeight > 0) IVoteEscrow(_ve).voting(_tokenId);
    totWeightsPerEpoch[_time] += _totalWeight;
    usedWeights[_tokenId] = (_usedWeight);
  }

  /// @notice claim LP gauge rewards
  function claimRewards(address[] memory _gauges) external {
    for (uint i = 0; i < _gauges.length; i++) {
      IGauge(_gauges[i]).getReward(msg.sender);
    }
  }

  /// @notice claim bribes rewards given a TokenID
  function claimBribes(address[] memory _bribes, address[][] memory _tokens, uint _tokenId) external {
    require(IVoteEscrow(_ve).isApprovedOrOwner(msg.sender, _tokenId), "not owner or approved");
    for (uint i = 0; i < _bribes.length; i++) {
      IBribe(_bribes[i]).getRewardForOwner(_tokenId, _tokens[i]);
    }
  }

  /// @notice claim fees rewards given a TokenID
  function claimFees(address[] memory _fees, address[][] memory _tokens, uint _tokenId) external {
    require(IVoteEscrow(_ve).isApprovedOrOwner(msg.sender, _tokenId), "not owner or approved");
    for (uint i = 0; i < _fees.length; i++) {
      IBribe(_fees[i]).getRewardForOwner(_tokenId, _tokens[i]);
    }
  }

  /// @notice claim bribes rewards given an address
  function claimBribes(address[] memory _bribes, address[][] memory _tokens) external {
    for (uint i = 0; i < _bribes.length; i++) {
      IBribe(_bribes[i]).getRewardForAddress(msg.sender, _tokens[i]);
    }
  }

  /// @notice claim fees rewards given an address
  function claimFees(address[] memory _bribes, address[][] memory _tokens) external {
    for (uint i = 0; i < _bribes.length; i++) {
      IBribe(_bribes[i]).getRewardForAddress(msg.sender, _tokens[i]);
    }
  }

  /// @notice check if user can vote
  function _voteDelay(uint _tokenId) internal view {
    require(block.timestamp > lastVoted[_tokenId] + voteDelay, "ERR: VOTE_DELAY");
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    GAUGE CREATION
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */
  /// @notice create multiple gauges
  function createPairGauges(
    address[] memory _targets
  ) external nonReentrant returns (address[] memory, address[] memory, address[] memory) {
    require(_targets.length <= 10, "max 10");
    address[] memory _gauge = new address[](_targets.length);
    address[] memory _int = new address[](_targets.length);
    address[] memory _ext = new address[](_targets.length);

    uint i = 0;
    for (i; i < _targets.length; i++) {
      (_gauge[i], _int[i], _ext[i]) = _createPairGauge(_targets[i]);
    }
    return (_gauge, _int, _ext);
  }

  /// @notice create multiple gauges
  function createMarketGauges(
    address[] memory _targets,
    address[] memory _flywheels
  ) external nonReentrant returns (address[] memory, address[] memory, address[] memory) {
    require(_targets.length == _flywheels.length, "len diff");
    require(_targets.length <= 10, "max 10");
    address[] memory _gauge = new address[](_targets.length);
    address[] memory _int = new address[](_targets.length);
    address[] memory _ext = new address[](_targets.length);

    uint i = 0;
    for (i; i < _targets.length; i++) {
      (_gauge[i], _int[i], _ext[i]) = _createMarketGauge(_targets[i], _flywheels[i]);
    }
    return (_gauge, _int, _ext);
  }

  /// @notice create a gauge
  function createPairGauge(
    address _target
  ) external nonReentrant returns (address _gauge, address _internal_bribe, address _external_bribe) {
    (_gauge, _internal_bribe, _external_bribe) = _createPairGauge(_target);
  }

  /// @notice create a gauge
  function createMarketGauge(
    address _target,
    address _flywheel
  ) external nonReentrant returns (address _gauge, address _internal_bribe, address _external_bribe) {
    (_gauge, _internal_bribe, _external_bribe) = _createMarketGauge(_target, _flywheel);
  }

  /// @notice create a gauge
  /// @param  _target  gauge target address
  function _createPairGauge(
    address _target
  ) internal VoterAdmin returns (address _gauge, address _internal_bribe, address _external_bribe) {
    require(gauges[_target] == address(0x0), "!exists");
    address _gaugeFactory = gaugeFactories[0];
    require(_gaugeFactory != address(0), "zero addr gauge f");

    //address underlying = ITarget(_target).underlying();

    // gov can create for any target, even non-Ionic pairs
    if (!isGovernor()) {
      // TODO verify that the target is an Ionic market in case the caller is not an admin
      revert("TODO verify that the target is an Ionic market in case the caller is not an admin");
    }

    if (address(bribeFactory) != address(0)) {
      // create internal and external bribe
      string memory _type = string.concat("Ionic market fees: ", IERC20(_target).symbol());
      _internal_bribe = IBribeFactory(bribeFactory).createBribe(owner(), _target, _type);

      _type = string.concat("Ionic Bribes: ", IERC20(_target).symbol());
      _external_bribe = IBribeFactory(bribeFactory).createBribe(owner(), _target, _type);
    }

    // create gauge
    _gauge = IGaugeFactory(_gaugeFactory).createPairGauge(
      base,
      _ve,
      _target,
      address(this),
      _internal_bribe,
      _external_bribe
    );

    // approve spending for $ion - used in IGauge(_gauge).notifyRewardAmount()
    IERC20(base).approve(_gauge, type(uint).max);

    // save data
    internal_bribes[_gauge] = _internal_bribe;
    external_bribes[_gauge] = _external_bribe;
    gauges[_target] = _gauge;
    targetForGauge[_gauge] = _target;
    isGauge[_gauge] = true;
    isAlive[_gauge] = true;
    targets.push(_target);

    // update index
    supplyIndex[_gauge] = index; // new users are set to the default global state

    emit PairGaugeCreated(_gauge, msg.sender, _internal_bribe, _external_bribe, _target);
  }

  /// @notice create a gauge
  /// @param  _target  gauge target address
  function _createMarketGauge(
    address _target,
    address _flywheel
  ) internal VoterAdmin returns (address, address, address) {
    require(gauges[_target] == address(0x0), "!exists");
    address _gaugeFactory = gaugeFactories[0];
    require(_gaugeFactory != address(0), "zero addr gauge f");

    // gov can create for any target, even non-Ionic pairs
    if (!isGovernor()) {
      // TODO verify that the target is an Ionic market in case the caller is not an admin
      revert("TODO verify that the target is an Ionic market in case the caller is not an admin");
    }

    address _internal_bribe;
    address _external_bribe;

    // create gauge
    address _gauge = IGaugeFactory(_gaugeFactory).createMarketGauge(
      _flywheel,
      base,
      _ve,
      _target,
      address(this),
      _internal_bribe,
      _external_bribe
    );

    // approve spending for $ion - used in IGauge(_gauge).notifyRewardAmount()
    IERC20(base).approve(_gauge, type(uint).max);

    // save data
    internal_bribes[_gauge] = _internal_bribe;
    external_bribes[_gauge] = _external_bribe;
    gauges[_target] = _gauge;
    targetForGauge[_gauge] = _target;
    isGauge[_gauge] = true;
    isAlive[_gauge] = true;
    targets.push(_target);

    // update index
    supplyIndex[_gauge] = index; // new users are set to the default global state

    emit MarketGaugeCreated(_gauge, msg.sender, _internal_bribe, _external_bribe, _target);

    return (_gauge, _internal_bribe, _external_bribe);
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    VIEW FUNCTIONS
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

  /// @notice view the total length of the targets
  function length() external view returns (uint) {
    return targets.length;
  }

  /// @notice view the total length of the voted targets given a tokenId
  function targetVoteLength(uint tokenId) external view returns (uint) {
    return targetVote[tokenId].length;
  }

  function _gaugeFactories() external view returns (address[] memory) {
    return gaugeFactories;
  }

  function gaugeFactoriesLength() external view returns (uint) {
    return gaugeFactories.length;
  }

  function weights(address _target) public view returns (uint) {
    uint _time = _epochTimestamp();
    return weightsPerEpoch[_time][_target];
  }

  function weightsAt(address _target, uint _time) public view returns (uint) {
    return weightsPerEpoch[_time][_target];
  }

  function totalWeight() public view returns (uint) {
    uint _time = _epochTimestamp();
    return totWeightsPerEpoch[_time];
  }

  function totalWeightAt(uint _time) public view returns (uint) {
    return totWeightsPerEpoch[_time];
  }

  function _epochTimestamp() public view returns (uint) {
    return IMinter(minter).active_period();
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    DISTRIBUTION
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

  /// @notice notify reward amount for gauge
  /// @dev    the function is called by the minter each epoch. Anyway anyone can top up some extra rewards.
  /// @param  amount  amount to distribute
  function notifyRewardAmount(uint amount) external {
    //require(msg.sender == owner());

    // TODO figure out why it was not called before
    IMinter(minter).update_period();

    _safeTransferFrom(base, msg.sender, address(this), amount); // transfer the distro in
    uint _totalWeight = totalWeightAt(_epochTimestamp() - TWO_WEEKS); // minter call notify after updates active_period, loads votes - 2 weeks
    uint256 _ratio = 0;

    if (_totalWeight > 0) _ratio = (amount * 1e18) / _totalWeight; // 1e18 adjustment is removed during claim
    if (_ratio > 0) {
      index += _ratio;
    }

    emit NotifyReward(msg.sender, base, amount);
  }

  /// @notice distribute the LP Fees to the internal bribes
  /// @param  _gauges  gauge address where to claim the fees
  /// @dev    the gauge is the owner of the LPs so it has to claim
  function distributeFees(address[] memory _gauges) external {
    for (uint i = 0; i < _gauges.length; i++) {
      if (isGauge[_gauges[i]] && isAlive[_gauges[i]]) {
        IGauge(_gauges[i]).claimFees();
      }
    }
  }

  /// @notice Distribute the emission for ALL gauges
  function distributeAll() external nonReentrant {
    IMinter(minter).update_period();

    uint x = 0;
    uint stop = targets.length;
    for (x; x < stop; x++) {
      _distribute(gauges[targets[x]]);
    }
  }

  /// @notice distribute the emission for N gauges
  /// @param  start   start index point of the targets array
  /// @param  finish  finish index point of the targets array
  /// @dev    this function is used in case we have too many targets and gasLimit is reached
  function distribute(uint start, uint finish) public nonReentrant {
    IMinter(minter).update_period();
    for (uint x = start; x < finish; x++) {
      _distribute(gauges[targets[x]]);
    }
  }

  /// @notice distribute reward onyl for given gauges
  /// @dev    this function is used in case some distribution fails
  function distribute(address[] memory _gauges) external nonReentrant {
    IMinter(minter).update_period();
    for (uint x = 0; x < _gauges.length; x++) {
      _distribute(_gauges[x]);
    }
  }

  /// @notice distribute the emission
  function _distribute(address _gauge) internal {
    uint lastTimestamp = gaugesDistributionTimestamp[_gauge];
    uint currentTimestamp = _epochTimestamp();
    if (lastTimestamp < currentTimestamp) {
      _updateForAfterDistribution(_gauge); // should set claimable to 0 if killed

      uint _claimable = claimable[_gauge];

      // distribute only if claimable is > 0, currentEpoch != lastepoch and gauge is alive
      if (_claimable > 0 && isAlive[_gauge]) {
        claimable[_gauge] = 0;
        gaugesDistributionTimestamp[_gauge] = currentTimestamp;
        IGauge(_gauge).notifyRewardAmount(base, _claimable);
        emit DistributeReward(msg.sender, _gauge, _claimable);
      }
    }
  }

  /* -----------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
                                    HELPERS
    --------------------------------------------------------------------------------
    --------------------------------------------------------------------------------
    ----------------------------------------------------------------------------- */

  /// @notice update info for gauges
  /// @dev    this function track the gauge index to emit the correct $ion amount after the distribution
  function _updateForAfterDistribution(address _gauge) private {
    address _target = targetForGauge[_gauge];
    uint256 _time = _epochTimestamp() - TWO_WEEKS;
    uint256 _supplied = weightsPerEpoch[_time][_target];

    if (_supplied > 0) {
      uint _supplyIndex = supplyIndex[_gauge];
      uint _index = index; // get global index0 for accumulated distro
      supplyIndex[_gauge] = _index; // update _gauge current position to global position
      uint _delta = _index - _supplyIndex; // see if there is any difference that need to be accrued
      if (_delta > 0) {
        uint _share = (uint(_supplied) * _delta) / 1e18; // add accrued difference for each supplied token
        if (isAlive[_gauge]) {
          claimable[_gauge] += _share;
        }
      }
    } else {
      supplyIndex[_gauge] = index; // new users are set to the default global state
    }
  }

  /// @notice safeTransfer function
  /// @dev    implemented safeTransfer function from openzeppelin to remove a bit of bytes from code
  function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
    require(token.code.length > 0, "not contract");
    (bool success, bytes memory data) = token.call(
      abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
    );
    require(success && (data.length == 0 || abi.decode(data, (bool))), "call fail");
  }
}
