package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"html/template"
	"io"
	"net/http"
	"os"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	log "github.com/sirupsen/logrus"
)

var authToken string
var user string
var port string
var rec_url string
var auth_url string
var submit_url string

var (
	helloCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "webapp_calls",
			Help: "Number of webapp calls.",
		},
		[]string{"url"},
	)
)

func init() {
	prometheus.MustRegister(helloCounter)
	log.SetLevel(log.DebugLevel)

	port = os.Getenv("PORT")
	rec_url = os.Getenv("RECOMMEND_URL")
	auth_url = os.Getenv("AUTH_URL")
	submit_url = os.Getenv("SUBMIT_URL")

	log.Infof("Port: %v", port)
	if len(port) == 0 {
		log.Fatalf("Port wasn't passed. An env variable for port must be passed")
	}
}

func homePage(w http.ResponseWriter, r *http.Request) {
	tmpl := template.Must(template.ParseFiles("index.html"))
	helloCounter.With(prometheus.Labels{"url": "/"}).Inc()
	log.Debugf("Homepage handler was called")
	tmpl.Execute(w, nil)
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	log.Debugf("Login handler was called")
	helloCounter.With(prometheus.Labels{"url": "/login"}).Inc()
	username := r.FormValue("username")
	password := r.FormValue("password")
	loginData := map[string]string{"username": username, "password": password}
	jsonData, _ := json.Marshal(loginData)

	response, err := sendAPIRequest(auth_url+"/login", jsonData, "")
	if err != nil {
		log.Debugf("Error while sending request to auth server: %v", err)
		http.Error(w, "Error while sending request to auth server: "+err.Error(), http.StatusInternalServerError)
		return
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		log.Debugf("Auth server returned non-OK status: %v", response.Status)
		http.Error(w, "Authentication failed: "+err.Error(), http.StatusUnauthorized)
		return
	}

	var token map[string]string
	if err := json.NewDecoder(response.Body).Decode(&token); err != nil {
		log.Debugf("Invalid server response: %v", err)
		http.Error(w, "Invalid server response: "+err.Error(), http.StatusInternalServerError)
		return
	}

	authToken = token["token"]
	user = username
	http.Redirect(w, r, "/", http.StatusSeeOther)
	return
}

// add spot on index.html to display result beyond logging
func submissionHandler(w http.ResponseWriter, r *http.Request) {
	log.Debugf("Submission handler was called")
	helloCounter.With(prometheus.Labels{"url": "/submit"}).Inc()
	if authToken == "" {
		log.Debugf("Not authenticated")
		http.Error(w, "Not authenticated", http.StatusUnauthorized)
		return
	}

	// send request to user data server to alter user data
	query := map[string]string{
		"Username":  user,
		"Movie":     r.FormValue("movie name"),
		"Rating":    r.FormValue("rating"),
		"Operation": r.FormValue("operation"),
	}

	// Marshal requestData to JSON
	jsonData, err := json.Marshal(query)
	if err != nil {
		log.Debugf("Error marshaling request data: %v", err)
		http.Error(w, "Error marshaling request data: "+err.Error(), http.StatusInternalServerError)
		return
	}

	response, err := sendAPIRequest(submit_url+"/submit", jsonData, authToken)
	if err != nil {
		log.Debugf("Error while sending request to submit server: %v", err)
		http.Error(w, "Error while sending request to submit server: "+err.Error(), http.StatusInternalServerError)
		return
	}
	defer response.Body.Close()

	// Read and display the response
	responseBody, err := io.ReadAll(response.Body)
	if err != nil {
		log.Debugf("Error reading response: %v", err)
		http.Error(w, "Error reading response: "+err.Error(), http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, "Response from API: %s", responseBody)

	// http.Redirect(w, r, "/", http.StatusSeeOther)
	// return
}

func recommendationHandler(w http.ResponseWriter, r *http.Request) {
	log.Debugf("Recommendation handler was called")
	helloCounter.With(prometheus.Labels{"url": "/recommend"}).Inc()

	if authToken == "" {
		log.Debugf("Not authenticated")
		http.Error(w, "Not authenticated", http.StatusUnauthorized)
		return
	}

	response, err := sendAPIRequest(rec_url+"/recommend", nil, authToken)
	if err != nil {
		log.Debugf("Error while sending request to recommendation server: %v", err)
		http.Error(w, "Error while sending request to recommendation server: "+err.Error(), http.StatusInternalServerError)
		return
	}
	fmt.Fprintf(w, "Response from API: %s", response)

	// http.Redirect(w, r, "/", http.StatusSeeOther)
	// return
}

func sendAPIRequest(url string, jsonData []byte, token string) (*http.Response, error) {
	req, err := http.NewRequest("POST", url, bytes.NewBuffer(jsonData))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	return resp, nil
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
	r.HandleFunc("/", homePage)
	r.HandleFunc("/login", loginHandler)
	r.HandleFunc("/submit", submissionHandler)
	r.HandleFunc("/recommend", recommendationHandler)
	r.HandleFunc("/version", versionHandler)
	r.HandleFunc("/status", statusHandler)
	http.Handle("/", r)
	http.Handle("/metrics", promhttp.Handler())
	log.Infof("Starting up server")
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
