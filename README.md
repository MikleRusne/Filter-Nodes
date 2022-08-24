
FILTERNODES --- README
---
# Introduction
Artists frequently use nodes like Color Correction in 3ds materials to change the look of a pre-existing color map.
This is straight forward to bake, just rendermap the diffuse input.
But when combined in a chain with nodes like Falloff, it bakes unwanted artifacts into the final texture.
This script cleans textures by removing unwanted nodes like falloffs and VrayDirtMaterials which might exist for artistic effect in 3ds, 
while retaining nodes like Color Correction which perform operations that should occur in the final result.

# Architecture
The script uses graph recursion, acting on a "tree" and cleaning it, then attaching it to the leaf of an outer tree
## Main
The entry point of the script is _CleanTree_ function, which accepts a texturemap as input, and returns a tree of nodes cleaned of falloff, but otherwise similar to the original tree.
It traverses to the first desired node in the original tree and calls it _firstNode_. This will be the root of the new tree.
If every node has just one previous input, it stores it as the _previousNode_, and looks for a proper predecessor to it called _currentNode_, using the helper function _GetNext_. It repeats this process, with _currentNode_ as the new _previousNode_ until it encounters a node that cannot have a previous node, where it breaks out of its loop and returns the _firstNode_. It is facilitated in this process by the helper function _isEndPoint_, which sets up nodes like Bitmap or Checkers to stop the iterations.
If a node has more than one previous inputs, such as in the case of _Mix_, it calls a new instance of _CleanTree_ with this node as its root. Then it assigns the returned value to the proper input of the _Mix_ nodes. This process repeats for all input nodes of a multi-input node.
To use the script, call _CleanTree_ on the desired map. For example, to clean the diffuse map input of selected object's VrayMaterial, `$.material.texmap_diffuse = CleanTree $.material.texmap_diffuse`  

## Helpers
### AssignMap
AssignMap accepts a forwardNode and a map. The map must be an assignable texture map, and forwardNode must be a texture map with a single input.
It assigns the map to the input of the forwardNode. It exists to prevent nested _caseof_ clutter when you need to assign nodes in a line.
You can add more nodes by adding to the _caseof_ conditions.
### IsEndPoint
Accepts a node, returns true if it has no inputs i.e. it is a leaf. It exists to prevent _caseof_ checks in _CleanTree_ to create leaf nodes in the final tree. Treats unhandled nodes as leaf nodes.
If you want the script to handle more types of nodes, add to the _caseof_ conditions. Avoid changing the default.
### IsDesired
Accepts a node, returns if it should be included in the final tree. It is used in _GetNext_ to filter out nodes that shouldn't make it at all to the final tree.
### GetNext
Accepts a node, returns its closest desired input node, or undefined if there is no desired input node.
The node must have only one desired input. In case of nodes for which multiple inputs should be cleaned, add to _caseof_ in clean tree
In case of unhandled node, returns if input is an endpoint, undefined if it is not.
You can extend it to accept new types by adding conditions in _caseof_ to return the input of new types.
