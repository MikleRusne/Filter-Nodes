escapeEnable =true;
-- The entire script assumes that no colors are used, will add that later
-- Has some problems with node copying

-- Assumes backnode is a map
-- Also assumes there's no dependency cycle situation
fn AssignMap map forwardNode = (
	format "Assigning % to %\n" map.name forwardNode.name
	case classof(forwardNode) of(
		ColorCorrection:(
			forwardNode.map = map;
		)
		Mix:(
			forwardNode.map1 = map;
		)
		default:(
			format "Unhandled in AssignMap, % assigning to %\n" map.name forwardNode.name
		)
	)
)


-- Filter to stop looking for nodes and bake
fn isEndPoint _node =(
	case classof(_node) of(
		Bitmap:(
			return true;
		)
		Checker:(
			return true;
		)
		VrayColor:(
			return true;
		)
		ColorCorrection:(
			if ( _node.map ==undefined) then return true else return false;
		)
		Falloff:(
			if ( (_node.map1 == undefined) and (_node.map2 == undefined)) then return true else return false;
		)
		--Might be a gamma node but ignore for now
		ColorMap:(
			return true;
		)
		default:(
			format "Unhandled % in isEndPoint, returning true\n" _node.name;
			return true;
		)
	)
)

-- Filter to keep looking for more nodes if false
fn isDesired _node = (
	case classof(_node) of (
		Checker: return true;
		BitmapTexture: return true;
		ColorCorrection: return true;
		Mix: return true;
		ColorMap: return true;
		Noise: return true;
		default: return false;
	)
)

-- Filters undesired nodes like Falloff
-- Provides immediate predecessor safety
fn GetNext _node = (
	format "Getnext called on %\n" _node;
	case classof(_node) of(
		Falloff:(
			if ( (isDesired _node.map1) ==true ) then (
				print("Get next found a desired map in falloff node, returning it");
				return _node.map1 
			)else (
				print("Falloff doesn't have desired node, calling recursively on map1");
				return GetNext _node.map1;
			)
		)
		ColorCorrection:(
			if ( (isDesired _node.map) ==true ) then return _node.map else return GetNext _node.map;
		)
		Mix:(
			---What do
			print("GetNext for Mix is under development, returning first map for now");
			if ( (isDesired _node.map1) == true ) then return _node.map1 else return GetNext _node.map1;
		)
		default:(
			print("Encountered Unhandled in GetNext")
			if ( (isEndPoint _node) == true ) then (
				print("returning because Endpoint");
				return _node;
			)else(
				print("Not endpoint, returning undefined");
				return undefined;
			);
		)
	)
)





fn CleanNode _currentNode _previousNode = (
	if ( (_previousNode == undefined) or (_currentNode ==undefined)) then return undefined;
	_newCurrentNode= copy (GetNext _currentNode)
	--Assumes that GetNext has traversed to the first desired node, and now it can be assigned
	--to previousNode's map
	if (_newCurrentNode == _previousNode) then (
		print("NewcurrentNode same as previousNode")
		return undefined;
	)
	else (
		AssignMap _newCurrentNode _previousNode;
	)
	
	return _newCurrentNode;
);
--This can handle a single node at a time, mix nodes

--In case a mix node or a multi input node is encountered, it must still be assigned to current node
--Therefore check previousNode to be Mix before trying to get the next node
--I have only now noticed that the font in this editor is Comic Sans this will not stand
--Changing font needs you to change an ini file and if the track record stands, I'll have to reinstall Max

-- Split Nodes = {Mix, Composite}
-- Takes a node, cleans it of falloff until it encounters either a terminal node or split nodes
-- Returns the root node of the cleaned tree
fn CleanTree _startNode = (
	--FirstNode defines the new root of the cleaned tree
	local _firstNode = undefined;
	if (_startNode == undefined) then return undefined;
	format "CleanTree called on %\n" _startNode.name;
	local _currentNode = _startNode;
	local _hasPreviousNode = true;
	--In case there's an infinite loop
	local _safety = 0;
	local _safetyLimit = 10;
	
	--There has to be a better way for this organization
	--I will update later
	local _previousNode = _currentNode;
	if (isDesired _previousNode == false) then _currentNode = GetNext _currentNode
	_hasPreviousNode =true;
	
	while (_hasPreviousNode==true) do (
		_safety+=1;
		_previousNode = _currentNode;
		if ( (_firstNode == undefined) and ( (isDesired _previousNode) == true) ) then (
			format "Assigning % as firstNode for Tree starting at %\n" _previousNode.name _startNode.name;
			_firstNode = _previousNode;
		);
		format "PreviousNode: % | Current Node: %\n" _previousNode.name _currentNode.name
		
		-- Cases for when a node has several inputs
		-- Ignoring falloff because even if it has several inputs, only map1 is important...except sometimes		
		if classof(_previousNode)==Mix  then (
			print("Mix node encountered");
			--Somehow clean individual Color nodes
			--It is implied that there is no dependency cycle
			print("Cleaning mix input1");
			_previousNode.map1 = CleanTree _previousNode.map1;
			print("Cleaning mix input2");
			_previousNode.map2 = CleanTree _previousNode.map2;
			print("Cleaning mix mask");
			_previousNode.mask = CleanTree _previousNode.mask;
			return _firstNode;
		)else(
			_currentNode = CleanNode _currentNode _previousNode;
			if (_currentNode == undefined) then _hasPreviousNode = false;
			if (isEndPoint _currentNode == true) then _hasPreviousNode = false;
			
			if (_safety>_safetyLimit) then (
				print("Safety triggered");
				_hasPreviousNode =false;
			)
		)
	)
	return _firstNode;
)


_inputMaterial = $.material;
_newInput = CleanTree (copy $.material.diffuseMap);
y = rendermap _newInput filename:(maxFilePath + $.material.name + ".png") size:[1024,1024];
save y
close y
_neode = BitmapTexture bitmap:y;
rendermap _newInput;
$.material.diffuseMap =  _newInput;