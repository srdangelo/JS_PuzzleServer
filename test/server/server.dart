library simple_http_server;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:http_server/http_server.dart' show VirtualDirectory;
//import 'package:image/image.dart' ;


/* myClient and additional functions code from:
* http://stackoverflow.com/questions/25982796/sending-mass-push-message-from-server-to-client-in-dart-lang-using-web-socket-m
*/
class myClient {
  DateTime time = new DateTime.now();
  num clientID = 1;
  WebSocket _socket;

  myClient(WebSocket ws){
        _socket = ws;
        _socket.listen(messageHandler,
                       onError: errorHandler,
                       onDone: finishedHandler);
  }

  void write(String message){ _socket.add(message); }

  void messageHandler(String msg){
//      print(msg);
    if(msg[0] == "d"){
      //print (msg);
      String tempMsg = msg.substring(2);
      List<String> data = tempMsg.split(",");
      myState.updateBox(num.parse(data[0]), num.parse(data[1]), num.parse(data[2]), data[3]);
      logData('${time}, ${trial.trialNum}, ${tempMsg} \n', 'clientData.csv');
      //print (tempMsg);
    }
    if (msg[0] == "n"){
      //print(msg);
      String tempMsg = msg.substring(2);
      List<String> data = tempMsg.split(",");
      myState.assignNeighbor(num.parse(data[0]), data[1], num.parse(data[2]));
      myState.calculateScore();
    }
    if (msg[0] == "c"){
          //print(msg);
          String tempMsg = msg.substring(2);
          List<String> data = tempMsg.split(",");
          print (data);
          logData('Touch Down: ${data} \n', 'clientData.csv');
        }
    else if(msg[0] == "b"){
      String tempMsg = msg.substring(2);
      List<String> data = tempMsg.split(",");
      //print (data);
      myState.noDrag(num.parse(data[0]));
    }

  }

  void errorHandler(error){
     print('one socket got error: $error');
     removeClient(this);
    _socket.close();
  }

  void finishedHandler() {
    print('one socket had been closed');
    distributeMessage('one socket had been closed');
    removeClient(this);
    _socket.close();
  }
}

//List of Clients connected to the server
List<myClient> clients = new List();

//Function to Manage Clients
void handleWebSocket(WebSocket socket){
  print('Client connected!');
  myClient client = new myClient(socket);
  addClient(client);
}

//Serve denial requests
void serveRequest(HttpRequest request){
  request.response.statusCode = HttpStatus.FORBIDDEN;
  request.response.reasonPhrase = "WebSocket connections only";
  request.response.close();
}

//Send Message to all Clients
void distributeMessage(String msg){
   for (myClient c in clients)c.write(msg);
 }

void sendID (){
  num ID = 1;
  for (myClient e in clients){
     e.write("i: ${ID}, ${trial.trialNum}");
    ID ++;
  }
}

void logData(String msg, String filename){
  //final filename = 'data.csv';
  //print("logging"+filename);
  /*
  try{
    var file = new File(filename);
      var sink = file.openWrite(mode: FileMode.APPEND);
      sink.write(msg);
  } on FileSystemException catch (ex){
    print(ex);
  }
  catch (exception,stacktrace){
        print(exception);
        print(stacktrace);
  }
  *
   */
}

 void addClient(myClient c){
     clients.add(c);
 }

 void removeClient(myClient c){
      clients.remove(c);
 }


VirtualDirectory virDir;

var random = new Random();

//Box class, acting as general object
class Box{
  num x;
  num y;
  var color;
  num id;
  bool dragged;
  bool moved;
  num gl_newX = random.nextInt(400);
  num gl_newY = random.nextInt(400);
  //Image image;
  
  Box rightNeighbor = null;
  Box leftNeighbor = null;
  Box upperNeighbor = null;
  Box lowerNeighbor = null;
  
  Box parentGroup=null;//used to group boxes when they are connected to each other
  Box(this.id, this.x, this.y, this.color){
    dragged = false;
    moved=false;
    //image = decodeImage(new File("images/${color}.png").readAsBytesSync());
  }



  void move(num dx, num dy) {
    x = dx;
    y = dy;
    //Hard coded width and height here. The server cannot access image so...
    //That's the solution for now.
    //num width=image.width; 
    //num height=image.height;
    num width=100; 
    num height=100;
    //run recursively to move all boxes that are neighbors of the moved box
    if (leftNeighbor != null &&leftNeighbor.moved==false){
      leftNeighbor.moved=true;
      leftNeighbor.move(dx-width, dy);
    }
    if (rightNeighbor != null&&rightNeighbor.moved==false){
      rightNeighbor.moved=true;
      rightNeighbor.move(dx+width, dy);
    }
    if (upperNeighbor != null && upperNeighbor.moved==false){
      upperNeighbor.moved=true;
      upperNeighbor.move(dx, dy+height);
    }
    if (lowerNeighbor != null &&lowerNeighbor.moved==false){
      lowerNeighbor.moved=true;
      lowerNeighbor.move(dx, dy-height);
    }
  }

  void moveAround(){
        var dist = sqrt(pow((gl_newX - this.x), 2) + pow((gl_newY - this.y), 2));
        num head = atan2((gl_newY - this.y), (gl_newX - this.x));

        if(dist >= 1){
          num targetX = cos(head) + this.x;
          num targetY = sin(head) + this.y;
          move(targetX, targetY);
          }
        else{
          num targetX = (cos(head) * dist) + this.x;
          num targetY = (sin(head) * dist) + this.y;
          move(targetX, targetY);

          gl_newX = random.nextInt(1200);
          gl_newY = random.nextInt(800);
          //change to game width and hieght
        }

  }
  //return the root of the group to which box belongs
  Box getParent(Box box){
    if (box.parentGroup==null)
      return box;
    else return getParent(box.parentGroup);
  }
}


//State class manages all the object including motion, and most likely any interactions
//This state will be mirrored by the State class on the client
class State{

  DateTime time = new DateTime.now();

  //List of all objects in the scene that need to be communicated
  List<Box> myBoxes;

  var score = 100;

  State(){
    myBoxes = new List<Box>();
  }


  //add object
  addBox(Box newBox){
    myBoxes.add(newBox);
  }


  //Update State will be run in timed intervals setup in the Main();
  updateState(){
    for(Box box in myBoxes){

      //dont move if being dragged
      if(!box.dragged){

        //random movement
        //box.x = box.x + random.nextInt(15) * (1 - 2*random.nextDouble()).round();
        //box.y = box.y + random.nextInt(15) * (1 - 2*random.nextDouble()).round();
        
        if (box.parentGroup==null)//only move the leading box in the group
        {
          for (Box boxtemp in myBoxes)
            boxtemp.moved=false;
          box.moveAround();
          
        }
        

        //keep movement within the bounds 600x400 hardcoded for now
        if(box.x < 0){
          box.x = box.x * -1;
        }
        else if(box.x > 1200){
          box.x = box.x -15;
        }

        if(box.y < 0){
          box.y = box.y * -1;
        }
        else if(box.y > 800){
          box.y = box.y -15;
        }
      }
    }
    sendState();

  }

  //Send state to all the clients, comes in the form of [object id, x, y, color]
  sendState(){
    String msg = "u:";
    for(Box box in myBoxes){
      msg = msg + "${box.id},${box.x},${box.y},${box.color};";
    }
    distributeMessage(msg);
    sendID();
    String phaseBreak = "p:${trial.phaseBreak}";
    distributeMessage(phaseBreak);
    try{
      logData('${time}, ${trial.trialNum}, ${msg} \n', 'gameStateData.csv');
    }
    catch (exception,stacktrace){
      print(exception);
      print(stacktrace);
    }

  }

  //simple command to toggle the dragging interaction
  noDrag(num id){
    for(Box box in myBoxes){
      if(id == box.id){
        box.dragged = false;
      }
    }
  }

  //if a object is dragged, this is called when the 'd' command is recieved
  updateBox(num id, num x, num y, String color){
    bool found = false;
    for(Box box in myBoxes){
      if(id == box.id){
        //box.x = x;
        //box.y = y;
        box.move(x, y);
        box.color = color;
        found = true;
        box.dragged = true;
      }
    }
    if(found == false){
      Box temp = new Box(id, x, y, color);
      myBoxes.add(temp);
    }
    for (Box box in myBoxes){
      box.moved=false;
    }
  }

  assignNeighbor (num id, String side, num neighbor){
    for(Box box in myBoxes){
      if(id == box.id){
        if (side == 'right'){
          box.rightNeighbor = myBoxes[neighbor - 1];
          box.rightNeighbor.leftNeighbor=box;
          //box.snap();
          assignParent(box,box.rightNeighbor);
        }
        if (side == 'left'){
          box.leftNeighbor = myBoxes[neighbor - 1];
          box.leftNeighbor.rightNeighbor=box;
          //box.snap();
          assignParent(box.leftNeighbor,box);
        }
        if (side == 'upper'){
          box.upperNeighbor = myBoxes[neighbor - 1];
          box.upperNeighbor.lowerNeighbor=box;
          //box.snap();
          assignParent(box,box.upperNeighbor);
        }
        if (side == 'lower'){
          box.lowerNeighbor = myBoxes[neighbor - 1];
          box.lowerNeighbor.upperNeighbor=box;
          //box.snap();
          assignParent(box.lowerNeighbor,box);
       }
      }
    }
  }
  
  assignParent (Box box1, Box box2){
    //assign box2's group as box1 if box1 has no parent
    //otherwise, assign box2's group as box1's parent group
    if (box1.parentGroup==null){//box1 is a root
      if (box2.parentGroup==null)//if box2 is a root
      {
        if (box1!=box2)//check to make sure these two are not the same box 
        {
          box2.parentGroup=box1;
                  print('parent:'+box1.id.toString());
        }
        //else do nothing
      }
        
      else
      {
        //if box2 belongs to some group
        assignParent(box1,box2.parentGroup);
      }
    }
    else//box1 belongs to some group
    {
      if (box2.parentGroup==null)//if box2 is a root
        assignParent(box1.parentGroup,box2);
      else
      {
        //if both box1 and box2 belongs to some group
        assignParent(box1.parentGroup,box2.parentGroup);
      }
    }
  }
  calculateScore(){
      score=0;
      int count=0;
      for(Box box in myBoxes){
        if (box.parentGroup==null)
        {
          count++;
        }
      }
      
      if (count==1)
        trial.transition();
      if (count>1){
        score=100*(myBoxes.length-count+1)/myBoxes.length; 
      }
      var sendScore = "s: ${score} \n";
      distributeMessage(sendScore);
    }

}


//initalize myState global var.
State myState;
Trial trial;



//server handling the path for files, might not be needed
//void directoryHandler(dir, request) {
//  var indexUri = new Uri.file(dir.path).resolve('test.html');
//  virDir.serveFile(new File(indexUri.toFilePath()), request);
//}

class Trial{
  var phase = 'TRIAL ZERO';
  num trialNum = 0;
  bool phaseBreak = true;

Trial () {
 transition();
}

  void setup(order){
    myState = new State();
    num i = 1;
    var piece;
    for (piece in order){
      //String boxNum = 'box' +  i.toString();
      //setup state and some test objects
      Box box = new Box(i, random.nextInt(800), random.nextInt(1000), piece);
      myState.addBox(box);
      i++;
      }
    }

  void transition() {
     List<String> order = [
                           ['plaid1', 'plaid2', 'plaid3', 'plaid4', 'plaid5', 'plaid6', 'plaid7', 'plaid8', 'plaid9'],
                           ['red', 'blue', 'green', 'black'],
                           ['red', 'blue', 'green', 'purple'],
                           ['red', 'blue', 'green',  'black']];
     switch(phase){
          case 'TRIAL ZERO':
              phase = 'BREAK';
              phaseBreak = true;
              setup([]);
              new Timer(const Duration(seconds : 10), () {
                 transition();
              });
              break;
          case 'BREAK':
              phase = 'TRIAL ONE';
              phaseBreak = false;
              trialNum += 1;
              setup(order[0]);
              break;
          case 'TRIAL ONE':
              phase = 'BREAK1';
              phaseBreak = true;
              setup([]);
              new Timer(const Duration(seconds : 10), () {
                  transition();
              });
              break;
           case 'BREAK1':
              phase = 'TRIAL TWO';
              myState.score = 100;
              phaseBreak = false;
              trialNum += 1;
              setup(order[1]);
              break;
           case 'TRIAL TWO':
              phase = 'TRIAL THREE';
              myState.score = 100;
              phaseBreak = false;
              trialNum += 1;
              setup(order[2]);
              break;
           case 'TRIAL THREE':
              phase = 'TRIAL FOUR';
              myState.score = 100;
              phaseBreak = false;
              trialNum += 1;
              setup(order[3]);
              break;
           }
      
   }
  
}


void main() {

  //server pathing
  var pathToBuild = "C:\\Users\\SESPWalkup\\Desktop\\JS_PuzzleServer-master2\\test\\build\\web\\";

  var staticFiles = new VirtualDirectory(pathToBuild);
  staticFiles.allowDirectoryListing = true;
  staticFiles.directoryHandler = (dir, request) {
    var indexUri = new Uri.file(dir.path).resolve('test.html');
    staticFiles.serveFile(new File(indexUri.toFilePath()), request);
  };
  //serve the test.html to port 8080
  HttpServer.bind('127.0.0.1', 8085).then((server) {
    server.listen(staticFiles.serveRequest);
  });

  //setup websocket at 4040
  runZoned(() {
    HttpServer.bind('127.0.0.1', 4040).then((server) {
      server.listen((HttpRequest req) {
        if (req.uri.path == '/ws') {
          // Upgrade a HttpRequest to a WebSocket connection.
          WebSocketTransformer.upgrade(req).then((handleWebSocket));
         }
        else {
          print("Regular ${req.method} request for: ${req.uri.path}");
          serveRequest(req);
          }
      });
    });
  },
  onError: (e) => print(e));



  trial = new Trial();



//  //setup state and some test objects
//  myState = new State();
//  Box box1 = new Box(1, random.nextInt(600), random.nextInt(400), 'red');
//  myState.addBox(box1);
//  Box box2 = new Box(2, random.nextInt(600), random.nextInt(400), 'green');
//  myState.addBox(box2);
//  Box box3 = new Box(3, random.nextInt(600), random.nextInt(400), 'blue');
//  myState.addBox(box3);
//  Box box4 = new Box(4, random.nextInt(600), random.nextInt(400), 'yellow');
//  myState.addBox(box4);
//  Box box5 = new Box(5, random.nextInt(600), random.nextInt(400), 'purple');
//  myState.addBox(box5);


  //setup times to update the state and send out messages to clients out with state information
  //running at about 15fps
  new Timer.periodic(const Duration(milliseconds : 30), (timer) => myState.updateState());
  //new Timer.periodic(const Duration(milliseconds : 80), (timer) => myState.sendState());

}