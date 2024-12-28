model WumpusUserInteraction

global {
    int grid_size <- 6;
    int gold_number <- 1;
    float cell_size <- 10.0;
    bool game_over <- false;
    
    init {
        // Créer la grille de rectangles
        loop i from: 0 to: grid_size - 1 {
            loop j from: 0 to: grid_size - 1 {
                create Rectangle {
                    location <- {i * cell_size + cell_size / 2, j * cell_size + cell_size / 2};
                    grid_x <- i;
                    grid_y <- j;
                }
            }
        }

        // Placer le personnage en bas à gauche
        create Person {
            location <- {cell_size / 2, grid_size * cell_size - cell_size / 2};
        }

        // Placement intelligent des éléments de jeu
        list<Rectangle> available_cells <- Rectangle where (each.grid_x > 0 and each.grid_y > 0);
        
        // Placer le Wumpus
        Rectangle wumpus_cell <- any(available_cells);
        create Wumpus {
            location <- wumpus_cell.location;
            wumpus_cell.has_wumpus <- true;
        }
        available_cells >> wumpus_cell;

        // Placer l'or
        loop times: gold_number {
	        Rectangle gold_cell <- any(available_cells);
	        create Gold {
	            location <- gold_cell.location;
	            gold_cell.has_gold <- true;
	        }
	        available_cells >> gold_cell;
		}
        // Créer des fosses
        loop times: 5 {
            Rectangle pit_cell <- any(available_cells);
            create Pit {
                location <- pit_cell.location;
                pit_cell.has_pit <- true;
            }
            available_cells >> pit_cell;
        }

        // Mettre à jour les chemins sécurisés et les indicateurs
        do update_safe_paths;
        ask Person[0] {do update_game_indicators;}
    }

    // Action pour mettre à jour les chemins sécurisés
    action update_safe_paths {
        ask Rectangle {
            is_safe_path <- true;
        }
        
        // Marquer les cellules adjacentes aux dangers comme non sécurisées
        ask Rectangle where (each.has_pit or each.has_wumpus) {
            list<Rectangle> nearby <- Rectangle where (
                abs(each.grid_x - self.grid_x) <= 1 and 
                abs(each.grid_y - self.grid_y) <= 1
            );
            
            loop rect over: nearby {
                rect.is_safe_path <- false;
            }
        }
    }

    // Action de fin de jeu améliorée
    action end_game(bool win) {
        game_over <- true;
        if (win) {
            write "🏆 FÉLICITATIONS ! Vous avez récupéré l'or et survécu !";
        } else {
            write "❌ GAME OVER ! Votre aventure dans le monde du Wumpus se termine ici.";
        }
        do pause;
    }
}

species Rectangle skills: [] {
    int grid_x;
    int grid_y;
    float length <- 10.0;
    float width <- 10.0;
    rgb color <- rgb("skyblue");
    bool has_wumpus <- false;
    bool has_gold <- false;
    bool has_pit <- false;
    bool has_breeze <- false;
    bool has_stench <- false;
    bool is_safe_path <- true;
    bool is_near_gold <- false;
    bool is_near_danger <- false;

    aspect basic {
        rgb cell_color <- color;
        
        // Coloration des cellules en fonction des indices
        if (!is_safe_path) { cell_color <- rgb(255,99,71, 150); } // Rouge semi-transparent pour les zones dangereuses
        if (has_breeze) { cell_color <- rgb(173,216,230); } // Bleu clair pour la brise
        if (has_stench) { cell_color <- rgb(255,228,196); } // Beige pour l'odeur
        if (is_near_gold) { cell_color <- rgb(255,215,0, 150); } // Or semi-transparent
        
        draw square(length) color: cell_color border: #white;
    }
}

species Pit skills: [] {
    float size <- 5;

    aspect basic {
        draw circle(size / 3) color: #black;
    }
}

species Person skills: [] {
    float size <- 5;
    int current_x <- 0;
    int current_y <- grid_size - 1;
    bool has_arrow <- true;
    bool has_gold <- false;

    bool is_move_valid(int x, int y) {
        return x >= 0 and x < grid_size and y >= 0 and y < grid_size;
    }

    action update_game_indicators {
        // Réinitialiser tous les indicateurs
        ask Rectangle {
            has_breeze <- false;
            has_stench <- false;
            is_near_gold <- false;
            is_near_danger <- false;
        }

        // Vérifier la proximité des éléments
        list<Rectangle> nearby_rectangles <- Rectangle where (
            abs(each.grid_x - self.current_x) <= 1 and 
            abs(each.grid_y - self.current_y) <= 1
        );
        
        loop rect over: nearby_rectangles {
            // Vérification des fosses
            if (rect.has_pit) {
                Rectangle current_cell <- first(Rectangle where (each.grid_x = self.current_x and each.grid_y = self.current_y));
                if (current_cell != nil) {
                    current_cell.has_breeze <- true;
                    current_cell.is_near_danger <- true;
                    write "💨 Une légère brise indique la présence d'un gouffre proche !";
                }
            }

            // Vérification du Wumpus
            if (rect.has_wumpus) {
                Rectangle current_cell <- first(Rectangle where (each.grid_x = self.current_x and each.grid_y = self.current_y));
                if (current_cell != nil) {
                    current_cell.has_stench <- true;
                    current_cell.is_near_danger <- true;
                    write "👃 Une odeur nauséabonde suggère la présence du Wumpus !";
                }
            }

            // Vérification de l'or
            if (rect.has_gold) {
                Rectangle current_cell <- first(Rectangle where (each.grid_x = self.current_x and each.grid_y = self.current_y));
                if (current_cell != nil) {
                    current_cell.is_near_gold <- true;
                    write "✨ L'or est proche ! Restez vigilant !";
                }
            }
        }

        // Mettre à jour les chemins sécurisés
        ask world {do update_safe_paths;}
    }

    action check_cell_interactions {
        // Trouver la cellule courante
        Rectangle current_cell <- first(Rectangle where (each.grid_x = current_x and each.grid_y = current_y));
        
        // Interaction avec l'or
        if (current_cell.has_gold) {
            has_gold <- true;
            write "💰 Bravo ! Vous avez trouvé l'or !";
            ask Gold {do die;}
            current_cell.has_gold <- false;
        }

        // Interaction avec les fosses
        if (current_cell.has_pit) {
            write "💀 Malheur ! Vous êtes tombé dans un gouffre mortel !";
            ask world {do end_game(false);}
        }

        // Interaction avec le Wumpus
        if (current_cell.has_wumpus) {
            write "👹 Le Wumpus vous a attrapé ! Fin de partie.";
            ask world {do end_game(false);}
        }
    }

    action shoot_arrow {
        if (has_arrow) {
            has_arrow <- false;
            write "🏹 Flèche tirée !";
            
            bool wumpus_killed <- false;
            ask Wumpus {
                int wumpus_x <- int(location.x / cell_size);
                int wumpus_y <- int(location.y / cell_size);
                
                // Vérifier si le Wumpus est sur la même ligne ou colonne
                if (wumpus_x = myself.current_x or wumpus_y = myself.current_y) {
                    // Trouver la cellule du Wumpus
                    Rectangle wumpus_cell <- first(Rectangle where (
                        int(location.x / cell_size) = wumpus_x and 
                        int(location.y / cell_size) = wumpus_y
                    ));
                    
                    if (wumpus_cell != nil) {
                        wumpus_cell.has_wumpus <- false;
                        wumpus_killed <- true;
                        do die;
                    }
                }
            }
            
            if (wumpus_killed) {
                write "🎯 Félicitations ! Vous avez éliminé le Wumpus !";
            } else {
                write "❌ Le tir a échoué. Le Wumpus reste en vie.";
            }
        } else {
            write "❌ Désolé, vous n'avez plus de flèche !";
        }
    }

    action move_direction(int dx, int dy) {
        int new_x <- current_x + dx;
        int new_y <- current_y + dy;
        
        if (is_move_valid(new_x, new_y)) {
            current_x <- new_x;
            current_y <- new_y;
            
            // Mettre à jour la position physique
            location <- {new_x * cell_size + cell_size / 2, new_y * cell_size + cell_size / 2};
            
            do update_game_indicators;
            do check_cell_interactions;
        }
    }

    action move_right { do move_direction(1, 0); }
    action move_left { do move_direction(-1, 0); }
    action move_up { do move_direction(0, -1); }
    action move_down { do move_direction(0, 1); }

    aspect basic {
        draw circle(size / 5) color: #pink border: #black;
        draw line([{location.x, location.y}, {location.x, location.y + size * 0.9}]) color: #black width: 2;
        draw line([{location.x - size / 2.5, location.y + size * 0.4}, {location.x + size / 2.5, location.y + size * 0.4}]) color: #black width: 1;
        draw line([{location.x, location.y + size * 0.8}, {location.x - size / 3, location.y + size * 1.4}]) color: #black width: 2;
        draw line([{location.x, location.y + size * 0.8}, {location.x + size / 3, location.y + size * 1.4}]) color: #black width: 2;
    }

    reflex check_game_end {
        // Vérifier si le joueur a l'or et est retourné au point de départ
        if (has_gold and current_x = 0 and current_y = grid_size - 1) {
            ask world {do end_game(true);}
        }
    }
}

species Wumpus skills: [] {
    float size <- 5;

    aspect basic {
        draw circle(size / 5) color: #red border: #black;
        draw line([{location.x - size / 2, location.y - size / 2}, {location.x + size / 2, location.y + size / 2}]) color: #black width: 2;
        draw line([{location.x - size / 2, location.y + size / 2}, {location.x + size / 2, location.y - size / 2}]) color: #black width: 2;
    }
}

species Gold skills: [] {
    float size <- 5.0;

    aspect basic {
        draw circle(size / 5) color: #yellow;
    }
}

experiment WumpusWorldGame type: gui {
    bool need_reset <- false;
    
    output {
        display main_display {
            species Rectangle aspect: basic;
            species Person aspect: basic;
            species Wumpus aspect: basic;
            species Gold aspect: basic;
            species Pit aspect: basic;
            
            event "mouse_down" action: check_move;
            event "mouse_menu" action: shoot_arrow;
            event "r" action: reset_game;
        }
    }

    action check_move {
        point mouse_loc <- #user_location;

        int clicked_x <- int(mouse_loc.x / cell_size);
        int clicked_y <- int(mouse_loc.y / cell_size);

        if (clicked_x = (Person[0].current_x + 1) and clicked_y = Person[0].current_y) {
            ask Person[0] {do move_right;}
        } else if (clicked_x = (Person[0].current_x - 1) and clicked_y = Person[0].current_y) {
            ask Person[0] {do move_left;}
        } else if (clicked_x = Person[0].current_x and clicked_y = (Person[0].current_y - 1)) {
            ask Person[0] {do move_up;}
        } else if (clicked_x = Person[0].current_x and clicked_y = (Person[0].current_y + 1)) {
            ask Person[0] {do move_down;}
        }
    }

    action shoot_arrow {
        ask Person[0] {do shoot_arrow;}
    }

    action reset_game {
        // Marquer le besoin de réinitialisation
        need_reset <- true;
        
        // Tuer toutes les espèces existantes
        ask Rectangle {do die;}
        ask Person {do die;}
        ask Wumpus {do die;}
        ask Gold {do die;}
        ask Pit {do die;}
        
        // Réinitialiser les variables globales et recréer la grille
        game_over <- false;
        
        // Créer la grille de rectangles
        loop i from: 0 to: grid_size - 1 {
            loop j from: 0 to: grid_size - 1 {
                create Rectangle {
                    location <- {i * cell_size + cell_size / 2, j * cell_size + cell_size / 2};
                    grid_x <- i;
                    grid_y <- j;
                }
            }
        }

        // Placer le personnage en bas à gauche
        create Person {
            location <- {cell_size / 2, grid_size * cell_size - cell_size / 2};
        }

        // Placement intelligent des éléments de jeu
        list<Rectangle> available_cells <- Rectangle where (each.grid_x > 0 and each.grid_y > 0);
        
        // Placer le Wumpus
        Rectangle wumpus_cell <- any(available_cells);
        create Wumpus {
            location <- wumpus_cell.location;
            wumpus_cell.has_wumpus <- true;
        }
        available_cells >> wumpus_cell;

        // Placer l'or
        Rectangle gold_cell <- any(available_cells);
        create Gold {
            location <- gold_cell.location;
            gold_cell.has_gold <- true;
        }
        available_cells >> gold_cell;

        // Créer des fosses
        loop times: 2 {
            Rectangle pit_cell <- any(available_cells);
            create Pit {
                location <- pit_cell.location;
                pit_cell.has_pit <- true;
            }
            available_cells >> pit_cell;
        }

        // Mettre à jour les chemins sécurisés et les indicateurs
        ask world {do update_safe_paths;}
        ask Person[0] {do update_game_indicators;}
    }
    
    reflex check_reset when: need_reset {
        need_reset <- false;
    }
}