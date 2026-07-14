-- Tree Cleanup Script
-- Identifies and deletes trees that are inside buildings

local cleanupConfig = {
	buildings = {
		{ name = "PlayerHouse", xMin = -54, xMax = -34, zMin = -49, zMax = -29 },
		{ name = "House1", xMin = -85, xMax = -65, zMin = -5, zMax = 5 },
		{ name = "House2", xMin = 67, xMax = 87, zMin = -15, zMax = 5 },
		{ name = "StudCenter", xMin = 37, xMax = 55, zMin = -45, zMax = -30 },
		{ name = "Shop", xMin = 35, xMax = 55, zMin = 42, zMax = 52 }
	},
	sceneryFolder = game.Workspace.Scenery
}

print("=== Starting Tree Cleanup ===")
print(string.format("Checking %s for trees inside buildings...", cleanupConfig.sceneryFolder.Name))

local treesToDelete = {}

-- Get all tree models from Scenery
for _, child in ipairs(cleanupConfig.sceneryFolder:GetChildren()) do
	if child:IsA("Model") and string.match(child.Name, "Tree") then
		local posX, posY, posZ = 0, 0, 0

		-- Try to get position from PrimaryPart
		if child.PrimaryPart then
			posX, posY, posZ = child.PrimaryPart.Position.X, child.PrimaryPart.Position.Y, child.PrimaryPart.Position.Z
		else
			-- Fall back to finding any BasePart with Position
			for _, part in ipairs(child:GetDescendants()) do
				if part:IsA("BasePart") then
					posX, posY, posZ = part.Position.X, part.Position.Y, part.Position.Z
					break
				end
			end
		end

		if posX == 0 and posY == 0 and posZ == 0 then
			warn(string.format("Tree '%s' has no valid position, skipping", child.Name))
		else
			print(string.format("Checking tree '%s' at (%.2f, %d, %.2f)", child.Name, posX, posY, posZ))

			local isInsideBuilding = false
			for _, b in ipairs(cleanupConfig.buildings) do
				if posX >= b.xMin and posX <= b.xMax and
				   posY >= 0 and posY <= 30 and
				   posZ >= b.zMin and posZ <= b.zMax then
					isInsideBuilding = true
					print(string.format("  -> Tree is INSIDE %s! (X:%.2f within [%d,%d], Z:%.2f within [%d,%d])", 
						b.name, posX, math.floor(b.xMin), math.floor(b.xMax), posZ, math.floor(b.zMin), math.floor(b.zMax)))
				end
			end

			if isInsideBuilding then
				print(string.format("  -> MARKING %s for deletion", child.Name))
				table.insert(treesToDelete, child)
			end
		end
	end
end

print("\n=== Results ===")
print(string.format("Found %d trees inside buildings that need to be deleted", #treesToDelete))

for _, tree in ipairs(treesToDelete) do
	print(string.format("Deleting: game.Workspace.Scenery.%s", tree.Name))
	-- Safety check before deletion
	if tree then
		tree:Destroy()
	end
end

print("\n=== Cleanup Complete ===")
print("All trees inside buildings have been removed.")