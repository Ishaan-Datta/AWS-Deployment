package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"

	"github.com/gorilla/mux"
	_ "github.com/mattn/go-sqlite3"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	log "github.com/sirupsen/logrus"
)

type Tag struct {
	MovieTitle string `json:"movieTitle"`
	Rating     int    `json:"rating"`
}

type UserTags struct {
	Username string `json:"username"`
	Tags     []Tag  `json:"tags"`
}

var (
	helloCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "db_calls",
			Help: "Number of database calls.",
		},
		[]string{"url"},
	)
)

var db *sql.DB
var port string
var auth_url string

func init() {
	prometheus.MustRegister(helloCounter)

	log.SetLevel(log.DebugLevel)
	port = os.Getenv("PORT")
	auth_url = os.Getenv("AUTH_URL")
	log.Infof("Port: %v", port)
	if len(port) == 0 {
		log.Fatalf("Port wasn't passed. An env variable for port must be passed")
	}

	var err error
	// Open the database connection
	db, err = sql.Open("sqlite3", "./example.db")

	if err != nil {
		log.Fatalf("Failed to connect to the database: %s", err.Error())
	}
	log.Debugf("Connected to the database")

	// later movie ID
	query := `
    CREATE TABLE IF NOT EXISTS data (
		username VARCHAR(255),
    	movieTitle VARCHAR(255),
    	rating INT,
    	PRIMARY KEY (username, movieTitle)
	);
    `
	_, err = db.Exec(query)
	if err != nil {
		log.Debugf("Failed to create table: %s", err.Error())
	} else {
		log.Infof("Table 'data' created or already exists")
	}
}

// Initialize the database connection
// func initDB() {
//     var err error
//     dsn := "username:password@tcp(127.0.0.1:3306)/dbname"
//     db, err = sql.Open("mysql", dsn)
//     if err != nil {
//         log.Fatalf("Failed to connect to database: %v", err)
//     }

//     // Test the connection
//     err = db.Ping()
//     if err != nil {
//         log.Fatalf("Failed to ping database: %v", err)
//     }
//     log.Println("Database connection established")
// }

func newHandler(w http.ResponseWriter, r *http.Request) {
	log.Infof("newhandler was called")
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, "Welcome to the auth API. Valid endpoints are /submit, /version, /status, /metrics")
	helloCounter.With(prometheus.Labels{"url": "/"}).Inc()
}

func submissionHandler(w http.ResponseWriter, r *http.Request) {
	log.Infof("submissionHandler was called")
	helloCounter.With(prometheus.Labels{"url": "/submit"}).Inc()

	// Extract the auth token from the request header
	authToken := r.Header.Get("Authorization")
	if len(authToken) == 0 {
		log.Debugf("Auth token is missing")
		http.Error(w, "Auth token is missing", http.StatusUnauthorized)
		return
	}
	// Verify the auth token
	if !verifyAuthToken(authToken) {
		log.Debugf("Invalid auth token")
		http.Error(w, "Invalid auth token", http.StatusUnauthorized)
		return
	}

	// Parse the request body
	var requestData map[string]string
	err := json.NewDecoder(r.Body).Decode(&requestData)
	if err != nil {
		log.Debugf("Invalid request body: %s", err.Error())
		http.Error(w, "Invalid request body: "+err.Error(), http.StatusBadRequest)
		return
	}

	// implement request routing: get,post,put,patch,delete
	user := requestData["Username"]
	movie := requestData["Movie"]
	rating, err := strconv.Atoi(requestData["Rating"])
	if err != nil {
		log.Debugf("Invalid rating: %s", err.Error())
		http.Error(w, "Invalid rating: "+err.Error(), http.StatusBadRequest)
		return
	}
	operation := requestData["Operation"]

	var db_error error
	var tags []Tag // modify so both other funcs call readrecords and set tag
	switch operation {
	case "add":
		tags, db_error = insertRecord(user, movie, rating)
	case "read":
		tags, db_error = readRecordByUsername(user)
	case "remove":
		tags, db_error = deleteRecord(user, movie)
	default:
		log.Debugf("Invalid operation")
		http.Error(w, "Invalid operation", http.StatusBadRequest)
		return
	}

	if db_error != nil {
		log.Debugf("Database error: %v", db_error)
		http.Error(w, "Database error: "+err.Error(), http.StatusInternalServerError)
		return
	}

	sendAPIResponse(w, tags)
}

func versionHandler(w http.ResponseWriter, r *http.Request) {
	log.Debugf("Version handler was called")
	helloCounter.With(prometheus.Labels{"url": "/version"}).Inc()
	fmt.Fprintf(w, "{'version':'1.0'}")
}
func statusHandler(w http.ResponseWriter, r *http.Request) {
	log.Debugf("Status handler was called")
	helloCounter.With(prometheus.Labels{"url": "/status"}).Inc()
	fmt.Fprintf(w, "{'status':'ok'}")
}

func verifyAuthToken(token string) bool {
	// Create the request payload
	payload := map[string]string{"token": token}
	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		log.Debugf("Failed to marshal payload: %s", err.Error())
		return false
	}

	// Create a new HTTP request
	req, err := http.NewRequest("POST", auth_url+"/token", bytes.NewBuffer(payloadBytes))
	if err != nil {
		log.Debugf("Failed to create request: %s", err.Error())
		return false
	}
	req.Header.Set("Content-Type", "application/json")

	// Send the request
	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		log.Debugf("Failed to send request: %s", err.Error())
		return false
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Debugf("Auth server responded with status: %v", resp.StatusCode)
		return false
	} else {
		return true
	}
}

func sendAPIResponse(w http.ResponseWriter, tags []Tag) {
	w.Header().Set("Content-Type", "application/json")
	response, err := json.Marshal(tags)
	if err != nil {
		log.Debugf("Failed to marshal response: %s", err.Error())
		http.Error(w, "Failed to marshal response", http.StatusInternalServerError)
		return
	}
	w.Write(response)
}

func insertRecord(username string, movie string, rating int) ([]Tag, error) {
	query := `
		INSERT INTO data (username, movieTitle, rating)
		VALUES (?, ?, ?)
		ON CONFLICT(username, movieTitle)
		DO UPDATE SET rating = excluded.rating;
	`
	_, err := db.Exec(query, username, movie, rating)
	if err != nil {
		return nil, err
	}
	log.Debugf("Record inserted.")

	tags, err := readRecordByUsername(username)
	return tags, err
}

func readRecordByUsername(username string) ([]Tag, error) {
	query := `SELECT movieTitle, rating FROM data WHERE username = ?`
	rows, err := db.Query(query, username)

	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tags []Tag

	for rows.Next() {
		var movieTitle string
		var rating int
		if err := rows.Scan(&movieTitle, &rating); err != nil {
			return nil, err
		}
		tags = append(tags, Tag{MovieTitle: movieTitle, Rating: rating})
	}

	if err := rows.Err(); err != nil {
		return nil, err
	}

	return tags, nil
}

func deleteRecord(username string, movie string) ([]Tag, error) {
	query := `DELETE FROM data WHERE username = ? AND movieTitle = ?`
	_, err := db.Exec(query, username, movie)
	if err != nil {
		return nil, err
	}
	log.Debugf("Record deleted.")
	tags, err := readRecordByUsername(username)
	return tags, err
}

func main() {
	r := mux.NewRouter()
	r.HandleFunc("/", newHandler)
	r.HandleFunc("/submit", submissionHandler)
	r.HandleFunc("/version", versionHandler)
	r.HandleFunc("/status", statusHandler)
	http.Handle("/", r)
	http.Handle("/metrics", promhttp.Handler())
	log.Infof("Starting up server")
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
