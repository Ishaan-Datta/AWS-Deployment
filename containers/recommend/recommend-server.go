package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	log "github.com/sirupsen/logrus"
)

type MovieResponse struct {
	Movies []string `json:"movies"`
}

// add prometheus endpoints + handler for /recommend
var movies = []string{
	"The Shawshank Redemption",
	"The Godfather",
	"The Dark Knight",
	"Pulp Fiction",
	"The Lord of the Rings: The Return of the King",
	"Forrest Gump",
	"Inception",
	"Fight Club",
	"The Matrix",
	"Goodfellas",
}

var (
	helloCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "rec_calls",
			Help: "Number of recommendation calls.",
		},
		[]string{"url"},
	)
)

var port string

func init() {
	prometheus.MustRegister(helloCounter)
	log.SetLevel(log.DebugLevel)

	port = os.Getenv("PORT")
	log.Infof("Port: %v", port)
	if len(port) == 0 {
		log.Fatalf("Port wasn't passed. An env variable for port must be passed")
	}
}

func newHandler(w http.ResponseWriter, r *http.Request) {
	log.Debugf("newhandler was called")
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, "Welcome to the recommendation API. Valid endpoints are /recommend, /version, /status, /metrics")
	helloCounter.With(prometheus.Labels{"url": "/"}).Inc()
}

// appropriate response if user has not selected any movies...
func recommendHandler(w http.ResponseWriter, r *http.Request) {
	log.Debugf("Recommend handler was called")
	helloCounter.With(prometheus.Labels{"url": "/recommend"}).Inc()

	// call authentication server to verify token by reading header before calling read on user-data

	// Shuffle the movies slice
	rand.Shuffle(len(movies), func(i, j int) {
		movies[i], movies[j] = movies[j], movies[i]
	})

	// Select the first 3 movies
	selectedMovies := movies[:3]

	// Create the response
	response := MovieResponse{
		Movies: selectedMovies,
	}

	// Marshal the response to JSON
	responseJSON, err := json.Marshal(response)
	if err != nil {
		http.Error(w, "Failed to marshal response", http.StatusInternalServerError)
		return
	}

	// Write the JSON response
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(responseJSON)
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

func main() {
	r := mux.NewRouter()
	r.HandleFunc("/", newHandler)
	r.HandleFunc("/recommend", recommendHandler)
	r.HandleFunc("/version", versionHandler)
	r.HandleFunc("/status", statusHandler)
	http.Handle("/", r)
	http.Handle("/metrics", promhttp.Handler())
	log.Infof("Starting up server")
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
