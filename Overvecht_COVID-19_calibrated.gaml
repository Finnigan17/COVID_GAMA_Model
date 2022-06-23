/**
* Name: utrechttest
* Based on the internal empty template. 
* Author: winke
* Tags: 
*/


model utrechttest

global {
	//	Definition of the variables used throughout the entire model
	int nb_agents <- 21700;
	int nb_infected_initial <- 127;
	int nb_immune_initial <- 0;
	float step <- 60 #mn;
	geometry shape <- envelope(shape_file_bounds);
	graph road_network; 
	
	date starting_date <- date("2020-09-01-00-00-00");
	int min_work_start <- 6;
	int max_work_start <- 8;
	int min_work_end <- 16; 
	int max_work_end <- 20;
	int shops_open <- 10;
	int shops_close <-22; 
	float min_speed <- 1.0 #km / #h;
	float max_speed <- 5.0 #km / #h; 
	
	float recovery_time <- 7 #days;
	
	int infections_start <- 0;
	int new_infections <- 0;
	list nb_new_infections_list;
	
	//	Values for the graph are calculated within this
	int nb_agents_infected <- nb_infected_initial update: people count (each.agent_status = "infected");
	int nb_new_infections <- infections_start update: new_infections;
	int nb_agents_immune <- nb_immune_initial update: people count (each.agent_status = "immune");
	int nb_agents_not_infected <- nb_agents - nb_infected_initial update: nb_agents - (nb_agents_infected + nb_agents_immune);
	float infection_rate update: nb_agents_infected/nb_agents;
	
	
	//	Need to include these files. Bounds has to do with the extent of GAMA area
    file shape_file_buildings <- file("../edited_shapefiles/Pand_Overvecht.shp");
    file shape_file_roads <- file("../includes/roads_overvecht.shp");
    file shape_file_bounds <- file("../includes/roads_overvecht.shp");

	//	These functions are run once the script is started 
	init{
    		create building from: shape_file_buildings with: [type::read ("category")] {
			if type = '2' {
				color <- #blue;
			}
		}
		
		create road from: shape_file_roads;
		road_network <- as_edge_graph(road);
	
		//	Creating the list of buildings and categorizing them for people
		list<building> residential_buildings <- building where (each.type="1");
	    list<building> industrial_buildings <- building  where (each.type="2") ;
	    list<building> shopping_buildings <- building where (each.type="4");
	    
	    create people number: nb_agents {
		    speed <- rnd(min_speed, max_speed);
		    start_work <- rnd(min_work_start, max_work_start);
		    end_work <- rnd(min_work_end, max_work_end);
		    living_place <- one_of(residential_buildings);
		    working_place <- one_of(industrial_buildings);
		    shopping_place <- one_of(shopping_buildings);
		    friends_place <- one_of(residential_buildings);
		    objective <- "resting";
		    location <- any_location_in (living_place); 
				}
		
		ask nb_infected_initial among people {
			agent_status <- "infected";
				}
	}
	
	reflex end_simulation when: infection_rate = 1.0 {
	do pause;
		}
		
	reflex write_data when: current_date.hour = 1 {
		add string(current_date.date + ";" + nb_new_infections) to: nb_new_infections_list;
		save (nb_new_infections_list) to: "save_data.txt" type: text;
	}
}

// 	Insert your model definition here

//	Defining the building and roads. Giving them colours and drawing them
//	once the experiment is started. 
 
species people skills:[moving]{
    float speed <- (2 + rnd(4)) #km/#h;
    string agent_status <- "not_infected";
	date infection_date <- date("");
	date recovery_date <- date("");
    point target;
    
    rgb color <- #green ;
    building living_place <- nil;
    building working_place <- nil;
    building shopping_place <- nil;
    building friends_place <- nil;
    int start_work ;
    int end_work ;
    string objective ;
    point target1 <- nil;

	//	This determines the probability at a certain distance that an agent is
	//	infected 
	reflex infect when: agent_status = "infected"{
		ask people at_distance 0.5 #m {
			if flip(0.00134) and agent_status != "immune"{
		    	agent_status <- "infected";
		    	infection_date <- current_date.date;
		    	recovery_date <- infection_date + recovery_time;
		    	new_infections <- new_infections + 1; 
		    		}
		    	}
		    }
		    
	reflex immune when: current_date.date = recovery_date and agent_status = "infected"{
		agent_status <- "immune";
	}
    
	//	Visual attributes of the agents
    aspect circle {
    	draw circle(5) color: color border: #black;
    		}
    
	//	This starts the working day when the time of day hits a certain hour
	//	and sends the agents to work.
	
	reflex is_week when: current_date.day_of_week < 6 and objective = "weekend"{
		objective <- "resting";
	}
	
	reflex is_weekend when: current_date.day_of_week > 5 and objective = "resting" {
		objective <- "weekend";
	}
	
	   reflex time_for_friend when: objective = "weekend" or objective = "resting"{
    	if flip(0.01) {
    		objective <- "friend";
    		target1 <- any_location_in(friends_place);
   			}
    	}
    	
    reflex time_to_end_walk when: objective = "friend" and target1 = nil {
    	if flip(0.1) {
    		objective <- "resting";
    		target1 <- any_location_in(living_place);
    	}
    }      	
    
    reflex time_for_work when: current_date.hour = start_work and objective = "resting"{
    	if flip(1) {
    		objective <- "working";
    	target1 <- any_location_in(working_place);
    	}
    		}
    	
    reflex time_for_home when: current_date.hour = end_work and objective = "working"{
    	objective <- "resting";
    	target1 <- any_location_in(living_place);
    }
    
    reflex time_for_shopping when: current_date.hour > shops_open and current_date.hour < shops_close 
    and objective = "resting" or objective = "weekend" {
    	if flip(0.2) {
    		objective <- "shopping";
    		target1 <- any_location_in(shopping_place);
    	}
    }
    
    reflex time_to_stop_shopping when: objective = "shopping" {
    	if current_date.hour = shops_close or flip(0.3) {
    		objective <- "resting";
    		target1 <- any_location_in(living_place);
    	}
    }
    
    reflex move when: target1 != nil {
    	do goto target: target1 on: road_network;
    	if target1 = location {
    		target1 <- nil;
    	}
    }
    }

//	Defining the buildings and how they will be inserted into the model
species building {
    string type; 
    rgb color <- #gray  ;
    aspect base {
    draw shape color: color ;
    }
}

//	Defining the road and how it will be inserted
species road {
    rgb color <- #black ;
    aspect base {
    draw shape color: color ;
    }
}

//	Running the experiment and defining experimental parameters
	experiment utrecht type: gui {
	parameter "Number of people agents" var: nb_agents category: "People" ;
	parameter "Earliest hour to start work" var: min_work_start category: "People" min: 2 max: 8;
    parameter "Latest hour to start work" var: max_work_start category: "People" min: 8 max: 12;
    parameter "Earliest hour to end work" var: min_work_end category: "People" min: 12 max: 16;
    parameter "Latest hour to end work" var: max_work_end category: "People" min: 16 max: 23;
    parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
    parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
	
	output {
		monitor "Infected people rate" value: infection_rate;
		monitor "Currently infected" value: nb_agents_infected;
		monitor "New infections" value: nb_new_infections;
		monitor "Recovered" value: nb_agents_immune;
		
	//	Displays the buildings and roads on screen
    	display city_display type: opengl {
        	species building aspect: base ;
        	species road aspect: base ;
        	species people aspect: circle;
    	}

	//	Displays the graphs of the infection rates on screen
		display chart_dis refresh:every(5 #cycles) {
			chart "COVID spreading" type: series {
//				data "susceptible" value: nb_agents_not_infected color: #green;
				data "infected" value: nb_agents_infected color: #red;
				data "immune" value: nb_agents_immune color: #yellow;
			}
		}
    	
	}
}


