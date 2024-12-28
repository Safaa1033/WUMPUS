model AdventureWorld

global {
    int world_size <- 6;
    point starting_point <- {1, 1};
    file icon_player <- file("../includes/girl.png");
    file icon_glitter <- file("../includes/glitter.png");
    file icon_breeze <- file("../includes/breeze.png");
    file icon_stench <- file("../includes/stench.png");
    int total_pits <- 2;
    int total_wumpus <- 1;
    int total_treasures <- 3;  // Increased number of treasures

    action calculate_breeze {
        loop cell over: AdventureCell {
            list<AdventureCell> neighbors <- cell neighbors_at 1;
            cell.has_breeze <- not empty(neighbors where (each.has_pit));
        }
    }

    action calculate_stench {
        loop cell over: AdventureCell {
            list<AdventureCell> neighbors <- cell neighbors_at 1;
            cell.has_stench <- not empty(neighbors where (each.has_wumpus));
        }
    }

    action calculate_glitter {
        loop cell over: AdventureCell {
            cell.has_glitter <- cell.has_treasure;
        }
    }

    action generate_indicators {
        do calculate_breeze;
        do calculate_stench;
        do calculate_glitter;
    }

    init {
        // Populate the grid with pits
        loop times: total_pits {
            AdventureCell pit <- one_of(AdventureCell where (each.type = "empty"));
            pit.type <- "pit";
            pit.has_pit <- true;
        }

        // Place the Wumpus in the grid
        loop times: total_wumpus {
            AdventureCell wumpus <- one_of(AdventureCell where (each.type = "empty"));
            wumpus.type <- "wumpus";
            wumpus.has_wumpus <- true;
        }

        // Add treasures to the grid
        loop times: total_treasures {
            AdventureCell treasure <- one_of(AdventureCell where (each.type = "empty"));
            treasure.type <- "treasure";
            treasure.has_treasure <- true;
        }

        // Spawn the player character
        create Explorer number: 1 {
            location <- starting_point;
        }

        // Generate environmental indicators
        do generate_indicators;
    }
}

grid AdventureCell width: world_size height: world_size {
    string type <- "empty";
    bool has_pit <- false;
    bool has_wumpus <- false;
    bool has_treasure <- false;
    bool has_breeze <- false;
    bool has_stench <- false;
    bool has_glitter <- false;

    reflex update_visual {
        if (type = "wumpus") {
            color <- #red;
        } else if (type = "treasure") {
            color <- #gold;
        } else if (type = "pit") {
            color <- #darkblue;
        } else if (has_breeze) {
            color <- #lightgray;
        } else if (has_stench) {
            color <- #orange;
        } else if (has_glitter) {
            color <- #pink;
        } else {
            color <- #white;
        }
    }
}

species Explorer {
    float movement_speed <- 0.01;
    list<point> safe_locations <- [];
    list<point> danger_locations <- [];
    list<point> visited_locations <- [];
    int collected_treasures <- 0;
    bool alive <- true;
    bool mission_complete <- false;

    reflex scan_environment {
        AdventureCell current <- AdventureCell(location);

        if (!(location in visited_locations)) {
            add location to: visited_locations;
            add location to: safe_locations;
        }

        list<AdventureCell> neighbors <- AdventureCell(location) neighbors_at 1;
        
        // Wumpus detection
        list<AdventureCell> wumpus_cells <- neighbors where (each.has_wumpus);
        if (not empty(wumpus_cells)) {
            write "IMMINENT DANGER! A Wumpus is in an adjacent cell!";
        }

        // Pit detection
        list<AdventureCell> pit_cells <- neighbors where (each.has_pit);
        if (not empty(pit_cells)) {
            write "IMMINENT DANGER! A pit is in an adjacent cell!";
        }

        // Handle dangers and treasure collection
        if (current.has_pit or current.has_wumpus) {
            alive <- false;
            write "Game Over! Explorer perished.";
            do die;
        } else if (current.has_treasure) {
            collected_treasures <- collected_treasures + 1;
            current.has_treasure <- false;
            current.type <- "empty";
            write "Treasure " + collected_treasures + " secured!";
            
            if (collected_treasures = total_treasures) {
                mission_complete <- true;
                write "Mission Complete! All treasures collected.";
                do leave_grid;
            }
        }

        do evaluate_cells;
    }

    reflex navigate when: alive and not mission_complete {
        list<AdventureCell> safe_neighbors <- AdventureCell(location) neighbors_at 1 
            where (!(each.has_pit) and !(each.has_wumpus));

        if (not empty(safe_neighbors) and (cycle mod int(1/movement_speed) = 0)) {
            AdventureCell next <- one_of(safe_neighbors);
            location <- next.location;
        } else {
            write "No safe path available!";
        }
    }

    action leave_grid {
        write "Explorer has exited the grid.";
        alive <- false;
        do die;
    }

    action evaluate_cells {
        safe_locations <- [];
        danger_locations <- [];
        loop cell over: AdventureCell {
            if (cell.location != location and !(cell.location in visited_locations)) {
                add cell.location to: (cell.has_pit or cell.has_wumpus ? danger_locations : safe_locations);
            }
        }
    }

    aspect default {
        draw image(icon_player) size: {12, 12};
    }
}

experiment AdventureSimulation type: gui {
    output {
        display AdventureMap {
            grid AdventureCell lines: #black;
            species Explorer;
        }
    }
}