package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	log "github.com/sirupsen/logrus"
)

type User struct {
	Name     string `json:"name"`
	Password string `json:"password"`
	Username string `json:"username"`
	Token    string `json:"token"`
}

var Userlist = []User{
	User{
		Name:     "Tracey",
		Password: "helloworld",
		Username: "tracey",
		Token:    "4d76c945-a946-4d2b-95a8-281aff55404f",
	},
	User{
		Name:     "Carisa",
		Password: "helloworld",
		Username: "carisa",
		Token:    "224b3200-d09b-4881-8a7b-d69d6d8ba543",
	},
	User{
		Name:     "Ernest",
		Password: "helloworld",
		Username: "ernest",
		Token:    "2115274e-34bc-4456-a1ee-1c4c171231a9",
	},
	User{
		Name:     "Amy",
		Password: "helloworld",
		Username: "amy",
		Token:    "5343b1d3-dfa3-4823-b544-e5907c3585f5",
	},
}

var (
	helloCounter = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "auth_calls",
			Help: "Number of authentication calls.",
		},
		[]string{"url"},
	)
)

var port string

func init() {
	prometheus.MustRegister(helloCounter)
	log.SetLevel(log.DebugLevel)

	log.Info(os.Environ())
	port = os.Getenv("PORT")
	log.Infof("Port: %v", port)
	if len(port) == 0 {
		log.Fatalf("Port wasn't passed. An env variable for port must be passed")
	}
}

func newHandler(w http.ResponseWriter, r *http.Request) {
	log.Infof("Newhandler was called")
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, "Welcome to the auth API. Valid endpoints are /login, /token, /version, /status, /metrics")
	helloCounter.With(prometheus.Labels{"url": "/auth"}).Inc()
}

func loginHandler(w http.ResponseWriter, r *http.Request) {
	helloCounter.With(prometheus.Labels{"url": "/login"}).Inc()
	log.Debugf("Login handler was called")
	// Parse the JSON request body
	var credentials struct {
		Username string `json:"username"`
		Password string `json:"password"`
	}
	if err := json.NewDecoder(r.Body).Decode(&credentials); err != nil {
		log.Debugf("Invalid request payload: %v", err)
		http.Error(w, "Invalid request payload: "+err.Error(), http.StatusBadRequest)
		return
	}

	for _, user := range Userlist {
		if user.Username == credentials.Username && user.Password == credentials.Password {
			response := struct {
				Token string `json:"token"`
			}{
				Token: user.Token,
			}
			w.Header().Set("Content-Type", "application/json")
			json.NewEncoder(w).Encode(response)
			return
		}
	}
	log.Debugf("Login information was invalid")
	http.Error(w, "Invalid username or password", http.StatusUnauthorized)
}

func tokenHandler(w http.ResponseWriter, r *http.Request) {
	helloCounter.With(prometheus.Labels{"url": "/token"}).Inc()
	log.Debugf("token handler was called")
	// Parse the JSON request body
	var requestBody struct {
		Token string `json:"token"`
	}
	if err := json.NewDecoder(r.Body).Decode(&requestBody); err != nil {
		log.Debugf("Invalid request payload: %v", err)
		http.Error(w, "Invalid request payload: "+err.Error(), http.StatusBadRequest)
		return
	}

	log.Debugf("Token: %v", requestBody.Token)

	tokenValid := false
	for _, user := range Userlist {
		log.Debugf("User token: %v", user.Token)
		if strings.TrimSpace(user.Token) == strings.TrimSpace(requestBody.Token) {
			tokenValid = true
			break
		}
	}

	if tokenValid {
		log.Debugf("Valid token was passed")
		w.WriteHeader(http.StatusOK)
	} else {
		log.Debugf("Invalid token was passed")
		w.WriteHeader(http.StatusUnauthorized)
	}
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
	r.HandleFunc("/login", loginHandler)
	r.HandleFunc("/token", tokenHandler)
	r.HandleFunc("/version", versionHandler)
	r.HandleFunc("/status", statusHandler)
	http.Handle("/", r)
	http.Handle("/metrics", promhttp.Handler())
	log.Infof("Starting up server")
	log.Fatal(http.ListenAndServe(":"+port, nil))
}
