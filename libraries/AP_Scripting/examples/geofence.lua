-- This LUA script takes two zones into account to do the geofence
-- Add the coordinates and the action to be taken for each fence breach

function createPoint(lat, lon)
    return { lat = lat, lon = lon, next = nil }
end
gcs:send_text(6, "Started..")

-- Create a table to store coordinate points of red zone
local redCoordinatePoints = {}
local numRedPoints = 14
local copter_land_mode_num = 9
local greenCoordinatePoints = {}
local numGreenPoints = 14

-- local testCoordinatePoints = {}
-- local numTestPoints = 4
    
    -- Add red zone points to the table, defining the linked list
    table.insert(redCoordinatePoints, createPoint(50.906376, 6.223196)) -- F1
    table.insert(redCoordinatePoints, createPoint(50.910998, 6.223086)) -- F2
    table.insert(redCoordinatePoints, createPoint(50.913740, 6.226769)) -- F3
    table.insert(redCoordinatePoints, createPoint(50.913135, 6.230278)) -- F4
    table.insert(redCoordinatePoints, createPoint(50.912821, 6.231021)) -- F5
    table.insert(redCoordinatePoints, createPoint(50.912073, 6.231793)) -- F6
    table.insert(redCoordinatePoints, createPoint(50.911361, 6.231674)) -- F7
    table.insert(redCoordinatePoints, createPoint(50.911074, 6.230432)) -- F8
    table.insert(redCoordinatePoints, createPoint(50.910664, 6.229780)) -- F9
    table.insert(redCoordinatePoints, createPoint(50.907942, 6.227214)) -- F10
    table.insert(redCoordinatePoints, createPoint(50.907432, 6.227156)) -- F11
    table.insert(redCoordinatePoints, createPoint(50.906610, 6.227501)) -- F12
    table.insert(redCoordinatePoints, createPoint(50.905917, 6.226675)) -- F13
    table.insert(redCoordinatePoints, createPoint(50.906223, 6.225644)) -- F14


    -- Add green zone points to the table, defining the linked list
    table.insert(greenCoordinatePoints, createPoint(50.906886, 6.223927)) -- G1
    table.insert(greenCoordinatePoints, createPoint(50.910946, 6.223798)) -- G2
    table.insert(greenCoordinatePoints, createPoint(50.913247, 6.226908)) -- G3
    table.insert(greenCoordinatePoints, createPoint(50.912701, 6.229972)) -- G4
    table.insert(greenCoordinatePoints, createPoint(50.912425, 6.230648)) -- G5
    table.insert(greenCoordinatePoints, createPoint(50.911652, 6.231214)) -- G6
    table.insert(greenCoordinatePoints, createPoint(50.911392, 6.229977)) -- G7
    table.insert(greenCoordinatePoints, createPoint(50.910842, 6.229131)) -- G8
    table.insert(greenCoordinatePoints, createPoint(50.909282, 6.228386)) -- G9
    table.insert(greenCoordinatePoints, createPoint(50.908253, 6.226671)) -- G10
    table.insert(greenCoordinatePoints, createPoint(50.907502, 6.226436)) -- G11
    table.insert(greenCoordinatePoints, createPoint(50.907083, 6.226495)) -- G12
    table.insert(greenCoordinatePoints, createPoint(50.906788, 6.226718)) -- G13
    table.insert(greenCoordinatePoints, createPoint(50.906549, 6.226418)) -- G14

-- Link the points to create a circular linked list for the zones
-- A zone is a polygon (a cycle), hence the linked list
function linkedList(points, numPoints)
    for i = 1, numPoints do
        local currentPoint = points[i]
        local nextIndex = (i % numPoints) + 1
        currentPoint.next = points[nextIndex]
    end
    return
end

linkedList(redCoordinatePoints, numRedPoints)
linkedList(greenCoordinatePoints, numGreenPoints)
-- linkedList(testCoordinatePoints, numTestPoints)

-- Calculate the cross product
function crossProduct(point1, point2, location)
    return (point1.lat - location.lat) * (point2.lon - location.lon) - (point1.lon - location.lon) * (point2.lat - location.lat)
end

-- Calculate the winding number, inspired in topic of Point-in-polygon-using-winding-number (stackoverflow.com)
function windingNumber(point, polygon)
    local wn = 0
    local current = polygon
    repeat
        local next = current.next
        if current.lat <= point.lat then
            if next.lat > point.lat and crossProduct(current, next, point) > 0 then
                wn = wn + 1
            end
        else
            if next.lat <= point.lat and crossProduct(current, next, point) < 0 then
                wn = wn - 1
            end
        end
        current = next
    until current == polygon
    return wn
end

function getLocation()
    -- local location = ahrs:get_position() location:lat() location:lng()
    local current_pos = ahrs:get_position()
    local home = ahrs:get_home() home:lat() home:lng()  

    if current_pos and home then  
   
        local point = createPoint(math.abs(current_pos:lat()/10000000), math.abs(current_pos:lng()/10000000))
        return point
    end

    local default = createPoint( math.abs(home:lat()/10000000), math.abs(home:lng()/10000000))
    return default

end

-- Verify if the location is inside the polygon
-- Define a global variable to keep track of the consecutive times the point is outside the fence

local outsideCount = 0
local detectRed = 0
local detectGreen = 0

function geoVerify()
    local location = getLocation()
    -- gcs:send_text(6, string.format("Current position- Lat:%.7f Long:%.7f", location.lat, location.lon))
    
    if location then

        local winding_red = windingNumber(location, redCoordinatePoints[1])
        if winding_red == 0 then
            if arming:is_armed() then
                arming:disarm()
                gcs:send_text(6, "Outside red fence...")
            end

        else
            -- gcs:send_text(6,"Inside red fence")
        end

        local winding_green = windingNumber(location, greenCoordinatePoints[1])
        if winding_green == 0 then
            gcs:send_text(6, "Outside green fence...")
            outsideCount = outsideCount + 1
        
            if outsideCount >= 5 then
                gcs:send_text(6, "Point has been outside the green fence for 10 consecutive times. Taking action...")
                
                vehicle:set_mode(copter_land_mode_num)
            end
        else
            -- gcs:send_text(6, "Inside green fence...")
            -- If the point is inside the fence, reset the consecutive outside counter
            outsideCount = 0
        end

        end

    return geoVerify, 500
end

return geoVerify()
