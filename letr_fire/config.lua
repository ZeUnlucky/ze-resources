Config = {

    fireInterval = 600, -- in seconds

    fires = {
        {
            label = "Fire at Legion Square west side!",
            position = vector3(143.38, -839.32, 31.02),
            amount = 30,
            shouldGround = true,
            distance = {
                x = 3,
                y = 3,
                z = 0
            }
        },
        {
            label = "Fire at Legion Square north side!",
            position = vector3(257.13, -830.32, 33.02),
            amount = 30,
            shouldGround = false,
            distance = {
                x = 2,
                y = 2,
                z = 5
            } 
        }, 
        {
            label = "Fire at the tree next to PHMC!",
            position = vector3(469.13, -364.32, 47.02),
            amount = 30,
            shouldGround = true,
            distance = {
                x = 10,
                y = 10,
                z = 0
            } 
        },  
        {
            label = "Fire at a gas station!",
            position = vector3(822.13, -1028.32, 27.02),
            amount = 60,
            shouldGround = true,
            distance = {
                x = 10,
                y = 10,
                z = 0
            } 
        },   
    }
}