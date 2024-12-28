model Wumpus_game

global {
	predicate patrol_desire <- new_predicate("patrol");
	predicate gold_desire <- new_predicate("gold");
	predicate goBack_desire <- new_predicate("goBack");
	string glitterLocation <- "glitterLocation";
	string odorLocation <- "odorLocation";
	string breezeLocation <- "breezeLocation";
	bool orden <- false;
	
	int gridSize <- 10;      
    float cellSize <- 100 / gridSize;

	int WumpusAreaNum<-2;
	int pitAreaNum<-3;
	
	list<float> moveValue <- [0.0, 90.0, 180.0, 270.0];
	
	init {
		create goldArea number:1;
		create wumpusArea number: WumpusAreaNum;
		create pitArea number: pitAreaNum;
		create player number: 1;
	}
	
	reflex stop when: length(goldArea) = 0 {
		do pause;
	}
}

species player skills: [moving] control: simple_bdi{
	
	rgb color <- #red;
	float mov;
	point lastPosition <- {-1,-1};
	bool wrongPlace <- false;
	init {
		gworld place <- gworld({1,1});
		location<-place.location;
		mov <- 0.0;
		do add_desire(patrol_desire);
	}
	
	perceive target:goldArea in: 1{ 
		
		ask glitterArea{
			do die;
		} 
		
		ask goldArea{
			do die;
			ask world{
				do pause;
			}
		} 
	}
	
	perceive target:wumpusArea in: 1{ 
		ask myself{
			do die;
			ask world{
				do pause;
			}
		} 
	}
	
	perceive target:pitArea in: 1{ 
		ask myself{
			do die;
			ask world{
				do pause;
			}
		} 
		
	}
	
	perceive target:odorArea in: 1{ 
		focus id:"odorLocation" var:location strength:10.0; 
		ask myself{
			wrongPlace <- true;
			if lastPosition = {-1, -1}{
				mov <- one_of(moveValue);
				do move heading: mov speed: cellSize;
			}
			do remove_desire(patrol_desire);
			do add_desire(goBack_desire);
		} 
	}
	
	perceive target:breezeArea in: 1{ 
		focus id:"breezeLocation" var:location strength:10.0; 
		ask myself{
			wrongPlace <- true;
			if lastPosition = {-1, -1}{
				mov <- one_of(moveValue);
				do move heading: mov speed: cellSize;
			}
			do remove_desire(patrol_desire);
			do add_desire(goBack_desire);
		} 
	}
	
	plan patrolling intention: patrol_desire{
		mov <- one_of(moveValue);
		do move heading: mov speed: cellSize;
		lastPosition <- location;
	}
	
	plan goBack intention: goBack_desire{
		if mov = 0.0{
			mov <- 180.0;
		}else if mov = 90.0{
			mov <- 270.0;
		}else if mov = 180.0{
			mov <- 0.0;
		}else{
			mov <- 90.0;
		}
		wrongPlace <- false;
		do move heading: mov speed: cellSize;
		do remove_desire(goBack_desire);
		do add_desire(patrol_desire);
	}
	
	
	perceive target:glitterArea in: 1{ 
		focus id:"glitterLocation" var:location strength:10.0; 
		ask myself{
			do remove_intention(patrol_desire, true);
		} 
	}
	
	
	
	// Reglas
	rule belief: new_predicate("glitterLocation") new_desire: get_predicate(get_belief_with_name("glitterLocation"));
	
	plan get_gold intention: new_predicate("glitterLocation") priority:5{
		
		if orden = true{
			if mov = 0.0{
				mov <- 180.0;
			}else if mov = 90.0{
				mov <- 270.0;
			}else if mov = 180.0{
				mov <- 0.0;
			}else{
				mov <- 90.0;
			}
			
			do move heading: mov speed: cellSize;
			orden <- false;
		}else{
			mov <- one_of(moveValue);
			
			do move heading: mov speed: cellSize;
			orden <- true;
		}
	}
	
	
	aspect bdi {
		draw file("../includes/character.png") size:cellSize;
	}
}

species odorArea{
	aspect base {
//	  draw square(cellSize) color: #brown border: #black;	
draw file("../includes/odor.png") size:cellSize;	
	}
}


species wumpusArea{
	init {
		gworld place <- one_of(gworld);
		loop while: place.location={1,1}{
			place<-one_of(gworld);
		}
		location <- place.location;
		list<gworld> vecinos <- [];
		ask place {
			vecinos <- neighbors;
		}
		
		loop i over: vecinos {
			create odorArea{
				location <- i.location;
			}
		}
	}
	aspect base {
//	  draw square(cellSize) color: #red border: #black;	
draw file("../includes/wumpus.png") size:cellSize;	
	}
}

species glitterArea{
	aspect base {
	  draw square(cellSize) color: rgb(0, 168, 22,0.25) border: #black;		
//draw file("../includes/hint.png") size:cellSize;
	}
}

species goldArea{
	init {
		gworld place <- one_of(gworld);
		location <- place.location;
		
		list<gworld> vecinos <- [];
		ask place {
			vecinos <- neighbors;
		}
		
		loop i over: vecinos {
			create glitterArea{
				location <- i.location;
			}
		}
	}
	
	
	perceive target:player in: 1{
		ask myself{
			do die;
		} 
	}
	
	aspect base {
//	  draw square(cellSize) color: rgb(255, 230, 0) border: #black;	
	  draw file("../includes/dollar.png") size:cellSize;	
	}
}

species breezeArea{
	aspect base {
	  draw square(cellSize) color: rgb(23, 23, 23, 0.25) border: #black;
	}
}


species pitArea{
	init {
		gworld place <- one_of(gworld);
		loop while: place.location={1,1}{
			place<-one_of(gworld);
		}
		location <- place.location;
		
		list<gworld> vecinos <- [];
		ask place {
			vecinos <- neighbors;
		}
		
		loop i over: vecinos {
			create breezeArea{
				location <- i.location;
			}
		}
	}
	
	aspect base {
	  draw square(cellSize) color: #black border: #black;		
	}
}



grid gworld width: gridSize height: gridSize neighbors:4 {
	rgb color <- rgb(255, 255, 255) ;
}



experiment Wumpus_experimento_1 type: gui {
	    parameter "Cells" var: gridSize min:1 max:100 ;

	    parameter "Wumpuss Number" var: WumpusAreaNum min:1 max:10 ;
	    parameter "Pit Number" var:pitAreaNum min:1 max:10;
	float minimum_cycle_duration <- 0.05;
	output {					
		display view1 { 
			grid gworld border: rgb(6, 115, 0);
			species goldArea aspect:base;
			species glitterArea aspect:base;
			species wumpusArea aspect:base;
			species odorArea aspect:base;
			species breezeArea aspect:base;
			species pitArea aspect:base;
			species player aspect:bdi;
		}
	}
}