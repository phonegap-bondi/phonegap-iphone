//Helper methods
//XHR
var HTTP = {
	get: function (url,headerValue) {
		var xhr = new XMLHttpRequest();
		xhr.open('GET', url, false); //synchronous
		xhr.setRequestHeader('X-BONDI', headerValue);
		xhr.onreadystatechange = function () {
			if (xhr.readyState == 4) {
				if (xhr.status == 200) {
					success(xhr);
				} else {
					failure(xhr);
				}
			}
		};
		xhr.send(null);
		return xhr.responseText;
	}
};

function arrayToObjectLiteral(a)
{
	var o = {};
	for(var i=0;i<a.length;i++)
	{
		o[a[i]]='';
	}
	return o;
}

//converts JSON string to BondiFile recursively to properly include parent (another BondiFile) attribute
function JSONtoBondiFile(JSONFile)
{
	var bondiFile = new BondiFile();
	for (var key in JSONFile) {
		if (key == "parent" && JSONFile[key] != "(null)")
			bondiFile[key] = JSONtoBondiFile(JSONFile[key]);
		else if ((key == "modified" || key == "created") && JSONFile[key] != "(null)"){
			bondiFile[key] = new Date(bondiFile[key]);
		}
		else
			bondiFile[key] = JSONFile[key];
	}
	return bondiFile;
}

String.prototype.startsWith = function(str) 
{return (this.match("^"+str)==str)}

// bondi
if (typeof(bondi) != 'object')
    bondi = {};

bondi.requestFeature = function ( successCallback,  errorCallback,  name){
	if (name.startsWith('http://bondi.omtp.org/api/1.1/filesystem'))
		successCallback(new FileSystemManager());
	else if(name.startsWith('http://bondi.omtp.org/api/1.1/devicestatus'))
		successCallback(new DeviceStatusManager());
	else if(name.startsWith('http://bondi.omtp.org/api/1.1/camera'))
		successCallback(new CameraManager());
	else if(name.startsWith('http://bondi.omtp.org/api/1.1/geolocation'))
		successCallback(bondi.geolocation);
	else
		errorCallback(new GenericError(SecurityError.PERMISSION_DENIED_ERROR));
	return new PendingOperation();
};

bondi.getFeatures = function () {
    return ["http://bondi.omtp.org/api/1.1/filesystem", 
    "http://bondi.omtp.org/api/1.1/devicestatus", 
    "http://bondi.omtp.org/api/1.1/camera", 
    "http://bondi.omtp.org/api/1.1/geolocation"];
}

GenericError = function(code) {
	this.code = code;
}

function DeviceAPIError() {
}
DeviceAPIError.UNKNOWN_ERROR = 10000;
DeviceAPIError.INVALID_ARGUMENT_ERROR = 10001;
DeviceAPIError.NOT_FOUND_ERROR = 10002;
DeviceAPIError.PENDING_OPERATION_ERROR = 10003;
DeviceAPIError.IO_ERROR = 10004;
DeviceAPIError.NOT_SUPPORTED_ERROR = 10005;

function SecurityError() {
}
SecurityError.PERMISSION_DENIED_ERROR = 20000;

PendingOperation = function() {
}
PendingOperation.prototype.cancel = function() {
	return false;
}

// bondi camera
function CameraError() {
}
CameraError.CAMERA_ALREADY_IN_USE_ERROR = 0;
CameraError.CAMERA_CAPTURE_ERROR = 1;
CameraError.CAMERA_LIVEVIDEO_ERROR = 2;

function BondiCamera() {
    this.ZOOM = 0;
    this.ZOOM_NOZOOM = 1;
    this.CONTRAST = 2;
    this.BRIGHTNESS = 3;
    this.COLORTEMPERATURE = 4;
    this.NIGHTMODE = 5;
    this.NIGHTMODE_OFF = 0;
    this.NIGHTMODE_ON = 1;
    this.MANUALFOCUS = 6;
    this.MANUALFOCUS_ON = 1;
    this.MANUALFOCUS_OFF = 0;
    this.FOCUS = 7;
    this.LIGHT = 8;
    this.FLASH = 9;
    this.FLASH_NO_FLASH = 0;
    this.FLASH_AUTOFLASH = 1;
    this.FLASH_FORCEDFLASH = 2;
    this.description = 'iphonecam';
}


BondiCamera.prototype.takePicture = function(successCallback, errorCallback, options) {
	bondi.camera.successCallback = successCallback;
	bondi.camera.errorCallback = errorCallback;
	if (options == undefined)
		options = {};
	HTTP.get('http://localhost:8080/BONDICamera/takePicture',JSON.stringify(options));
    return new PendingOperation();
}

BondiCamera.prototype.getSupportedFeatures = function() {
	return [];
}
BondiCamera.prototype.setFeature = function(featureID, valueID) {
	throw new GenericError(DeviceAPIError.INVALID_ARGUMENT_ERROR);
}
BondiCamera.prototype.requestLiveVideo = function(successCallback, errorCallback) {
	throw new Error("Not implemented");
}
BondiCamera.prototype.startVideo = function(successCallback, errorCallback, options) {
	throw new Error("Not implemented");
}
BondiCamera.prototype.stopVideo = function(successCallback, errorCallback) {
	throw new Error("Not implemented");
}

function CameraManager() {
	this._cams = [];
	this._cams.push(new BondiCamera());
}

CameraManager.prototype.cameraSuccess = function(path){
	this.successCallback(path);
}

CameraManager.prototype.cameraError = function(error){
	this.errorCallback(error);
}

CameraManager.prototype.getCameras = function(successCallback, errorCallback) {
	var cams = this._cams;
	setTimeout(function() {
		successCallback(cams);
	}, 1);
	return new PendingOperation();
}


PhoneGap.addConstructor(function() {
    if (typeof bondi.camera == "undefined") bondi.camera = new CameraManager();
});

// bondi geolocation
PhoneGap.addConstructor(function() {
    if (typeof bondi.geolocation == "undefined") bondi.geolocation = navigator.geolocation; //equals W3C Geolocation API
});

// bondi filesystem
function FileSystemManager(){
    this.maxPathLength = 9999; //should be unlimited (HFS+ or FAT32 depending on OS)	
	this.rootLocations = ["wgt-private", "documents", "images"];
}

FileSystemManager.prototype.fileSystemSuccess = function(file){
	this.successCallback(file);
}

FileSystemManager.prototype.fileSystemError = function(error){
	this.errorCallback(error);
}

FileSystemManager.prototype.getDefaultLocation = function(specifier) {
    if (specifier in arrayToObjectLiteral(this.rootLocations)) {
		var defaultLocation = HTTP.get('http://localhost:8080/BONDIFilesystem/getDefaultLocation',specifier);
		return defaultLocation;
    }
    else{		 
        throw new GenericError(DeviceAPIError.INVALID_ARGUMENT_ERROR);    
		return null;
	}
}
FileSystemManager.prototype.getRootLocations = function() {
	return this.rootLocations;
}
/*
//BONDI 1.0
FileSystemManager.prototype.resolve = function(location) {
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/resolve',location);
	if (returnString == DeviceAPIError.INVALID_ARGUMENT_ERROR){
		throw new GenericError(DeviceAPIError.INVALID_ARGUMENT_ERROR);
		return null;
	}
	else if (returnString == SecurityError.PERMISSION_DENIED_ERROR){
		throw new GenericError(SecurityError.PERMISSION_DENIED_ERROR);
		return null;
	}
	else{
		var tempFile = eval("(" + returnString + ")"); //JSON string
		return JSONtoBondiFile(tempFile);
	}	
}
*/

FileSystemManager.prototype.fileSystemResolveSuccess = function(file){
	if (file == DeviceAPIError.INVALID_ARGUMENT_ERROR){
		throw new GenericError(DeviceAPIError.INVALID_ARGUMENT_ERROR);
		return null;
	} else {
		var tempFile = eval("(" + file + ")");
		var bondiFile = JSONtoBondiFile(tempFile);
		this.successCallback(bondiFile);
	}
}

//BONDI 1.1
FileSystemManager.prototype.resolve = function(successCallback, errorCallback, location, mode) {
	var supportedModes = ["r", "a", "w"];
	if ( !(mode in arrayToObjectLiteral(supportedModes)))
		throw new GenericError(DeviceAPIError.INVALID_ARGUMENT_ERROR);
	bondi.filesystem.successCallback = successCallback;
	bondi.filesystem.errorCallback = errorCallback;
	HTTP.get('http://localhost:8080/BONDIFilesystem/resolve',formatPath(location)+';'+mode);
	return new PendingOperation();
}
FileSystemManager.prototype.registerEventListener = function(listener) {
	throw new Error("Not implemented");
}
FileSystemManager.prototype.unregisterEventListener = function(listener) {
	throw new Error("Not implemented");
}

function FileSystemListener(){
}
FileSystemListener.prototype.mountEvent = function(location) {
	throw new Error("Not implemented");
}
FileSystemListener.prototype.unmountEvent = function(location) {
	throw new Error("Not implemented");
}

function BondiFile(){
    this.parent = null;
    this.readOnly = false;
    this.isFile = false;
    this.isDirectory = false;
    this.created = new Date();
    this.modified = new Date();
    this.path = "";
    this.name = "";
    this.absolutePath = "";
    this.fileSize = 0;
	
	this.supportedModes = ["r", "a", "w"];
	this.supportedEncodings = ["UTF-8", "ISO8859-1"];
}

BondiFile.prototype.listFiles = function() {
    if (this.isFile)
		throw new GenericError(DeviceAPIError.IO_ERROR);
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/listFiles',this.absolutePath);
	if (returnString == SecurityError.PERMISSION_DENIED_ERROR){
		throw new GenericError(SecurityError.PERMISSION_DENIED_ERROR);
		return null;
	}
	var fileArray = eval(returnString);
	for (var i=0;i<fileArray.length;i++){
		fileArray[i] = JSONtoBondiFile(fileArray[i]);
	}
    return fileArray;
}

BondiFile.prototype.open = function(mode, encoding) {
    if (this.isDirectory)
		throw new GenericError(DeviceAPIError.IO_ERROR);
	if ( !(mode in arrayToObjectLiteral(this.supportedModes)) || !(encoding in arrayToObjectLiteral(this.supportedEncodings)) )
		throw new GenericError(DeviceAPIError.INVALID_ARGUMENT_ERROR);
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/open',this.absolutePath+';'+mode+';'+encoding);
	if (returnString == SecurityError.PERMISSION_DENIED_ERROR){
		throw new GenericError(SecurityError.PERMISSION_DENIED_ERROR);
		return null;
	} else {	
	//update FileStream attributes
		var fileStream = new FileStream();
		var fileInfo = eval("(" + returnString + ")"); //JSON string
		fileStream._position = fileInfo.position;
		fileStream.bytesAvailable = fileInfo.filesize!=fileStream._position?fileInfo.filesize - fileStream._position:-1;
		fileStream._eof = (fileStream.bytesAvailable == -1);
		
		fileStream.absolutePath = this.absolutePath;
		fileStream.mode = mode;
		fileStream.encoding = encoding;
	}
	
    return fileStream;
}
BondiFile.prototype.copyTo = function(successCallback, errorCallback, filePath, overwrite) {
	if(this.isDirectory)
		throw new GenericError(DeviceAPIError.IO_ERROR);
	bondi.filesystem.successCallback = successCallback;
	bondi.filesystem.errorCallback = errorCallback;
	HTTP.get('http://localhost:8080/BONDIFilesystem/copyTo',this.absolutePath+';'+formatPath(filePath)+';'+overwrite);
	return new PendingOperation();
}
BondiFile.prototype.moveTo = function(successCallback, errorCallback, filePath, overwrite) {
	if(this.isDirectory)
		throw new GenericError(DeviceAPIError.IO_ERROR);
	bondi.filesystem.successCallback = successCallback;
	bondi.filesystem.errorCallback = errorCallback;
	HTTP.get('http://localhost:8080/BONDIFilesystem/moveTo',this.absolutePath+';'+formatPath(filePath)+';'+overwrite);
	return new PendingOperation();
}

function formatPath(path){
	if (path.indexOf("/") == 0)
		return path;
	else
		return "/"+path;
}

BondiFile.prototype.createDirectory = function(dirPath) {
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/createDirectory',this.absolutePath+formatPath(dirPath));
	if (returnString == SecurityError.PERMISSION_DENIED_ERROR){
		throw new GenericError(SecurityError.PERMISSION_DENIED_ERROR);
		return null;
	}
	if (returnString == DeviceAPIError.IO_ERROR){
		throw new GenericError(DeviceAPIError.IO_ERROR);
		return null;
	}
	
	var tempFile = eval("(" + returnString + ")"); //JSON string
	return JSONtoBondiFile(tempFile);
}


BondiFile.prototype.createFile = function(filePath) {
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/createFile',this.absolutePath+formatPath(filePath));
	if (returnString == SecurityError.PERMISSION_DENIED_ERROR){
		throw new GenericError(SecurityError.PERMISSION_DENIED_ERROR);
		return null;
	}
	if (returnString == DeviceAPIError.IO_ERROR){
		throw new GenericError(DeviceAPIError.IO_ERROR);
		return null;
	}
	var tempFile = eval("(" + returnString + ")"); //JSON string
	return JSONtoBondiFile(tempFile);
}

BondiFile.prototype.resolve = function(filePath) {
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/resolve',this.absolutePath+formatPath(filePath));
	if (returnString == SecurityError.PERMISSION_DENIED_ERROR){
		throw new GenericError(SecurityError.PERMISSION_DENIED_ERROR);
		return null;
	}
	if (returnString == DeviceAPIError.INVALID_ARGUMENT_ERROR){ //remap exception, since same method is used as in FileSystemManager.resolve
		throw new GenericError(DeviceAPIError.IO_ERROR);
		return null;
	}
	var tempFile = eval("(" + returnString + ")"); //JSON string
	return JSONtoBondiFile(tempFile);
}

BondiFile.prototype.deleteDirectory = function(recursive) {
	if(this.isFile){
		throw new GenericError(DeviceAPIError.IO_ERROR);
		return false;
	}
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/deleteDirectory',this.absolutePath+';'+recursive);
	if (returnString == SecurityError.PERMISSION_DENIED_ERROR){
		throw new GenericError(SecurityError.PERMISSION_DENIED_ERROR);
		return false;
	}else if (returnString == DeviceAPIError.IO_ERROR){
		throw new GenericError(DeviceAPIError.IO_ERROR);
		return false;
	} else
		return true;
}

BondiFile.prototype.deleteFile = function() {
	if(this.isDirectory){
		throw new GenericError(DeviceAPIError.IO_ERROR);
		return false;
	}
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/deleteFile',this.absolutePath);
	if (returnString == SecurityError.PERMISSION_DENIED_ERROR){
		throw new GenericError(SecurityError.PERMISSION_DENIED_ERROR);
		return false;
	}else if (returnString == DeviceAPIError.IO_ERROR){
		throw new GenericError(DeviceAPIError.IO_ERROR);
		return false;
	} else
		return true;
}

function FileStream(){
    this._eof = true;
	FileStream.prototype.__defineGetter__("eof", function() { return this._eof });
	FileStream.prototype.__defineSetter__("eof", function(value) {;});
    this._position = 0;
	FileStream.prototype.__defineGetter__("position", function() { return this._position });
	FileStream.prototype.__defineSetter__("position", function(position) {
										  var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/seek',this.absolutePath+';'+this.mode+';'+position);
										  if (returnString == DeviceAPIError.IO_ERROR){
											throw new GenericError(DeviceAPIError.IO_ERROR);
										  } else { //update FileStream attributes
											var fileInfo = eval("(" + returnString + ")"); //JSON string
											this._position = fileInfo.position;
											this.bytesAvailable = fileInfo.filesize!=this._position?fileInfo.filesize - this._position:-1;
											this._eof = (this.bytesAvailable == -1);
											return fileInfo.data;
										  }
										  });
    this.bytesAvailable = -1; 
	
	//attributes transferred from BondiFile - not part of specification
	this.absolutePath = "";
	this.mode = "";
	this.encoding = "";
}
FileStream.prototype.close = function close(){
	HTTP.get('http://localhost:8080/BONDIFilesystem/close',this.absolutePath+';'+this.mode+';'+this.encoding);
	//reset attributes
	this._eof = true;
    this._position = 0;
    this.bytesAvailable = -1;
}
FileStream.prototype.read = function read(charCount){
	//charCount can be > than bytesAvailable (NSFileHandle.read)
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/read',charCount+';'+this.absolutePath+';'+this.mode+';'+this.encoding);

	if (returnString == DeviceAPIError.IO_ERROR){
		throw new GenericError(DeviceAPIError.IO_ERROR);
	} else { //update FileStream attributes
		var fileInfo = eval("(" + returnString + ")"); //JSON string
		this._position = fileInfo.position;
		this.bytesAvailable = fileInfo.filesize!=this._position?fileInfo.filesize - this._position:-1;
		this._eof = (this.bytesAvailable == -1);
		return fileInfo.data;
	}
}
FileStream.prototype.readBytes = function readBytes(byteCount){
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/readBytes',byteCount+';'+this.absolutePath+';'+this.mode+';'+this.encoding);
	if (returnString == DeviceAPIError.IO_ERROR){
		throw new GenericError(DeviceAPIError.IO_ERROR);
	} else { //update FileStream attributes
		var fileInfo = eval("(" + returnString + ")"); //JSON string
		this._position = fileInfo.position;
		this.bytesAvailable = fileInfo.filesize!=this._position?fileInfo.filesize - this._position:-1;
		this._eof = (this.bytesAvailable == -1);
		return fileInfo.data;
	}
}
FileStream.prototype.readBase64 = function readBase64(byteCount){
	var returnString = HTTP.get('http://localhost:8080/BONDIFilesystem/readBase64',byteCount+';'+this.absolutePath+';'+this.mode+';'+this.encoding);
	if (returnString == DeviceAPIError.IO_ERROR){
		throw new GenericError(DeviceAPIError.IO_ERROR);
	} else { //update FileStream attributes
		var fileInfo = eval("(" + returnString + ")"); //JSON string
		this._position = fileInfo.position;
		this.bytesAvailable = fileInfo.filesize!=this._position?fileInfo.filesize - this._position:-1;
		this._eof = (this.bytesAvailable == -1);
		return fileInfo.data;
	}
}
FileStream.prototype.write = function write(stringData){
	var stringResult = HTTP.get('http://localhost:8080/BONDIFilesystem/write',stringData +';'+this.absolutePath+';'+this.mode+';'+this.encoding);
	if (stringResult == DeviceAPIError.IO_ERROR){
		throw new GenericError(DeviceAPIError.IO_ERROR);
	} else { //update FileStream attributes
		var fileInfo = eval("(" + stringResult + ")"); //JSON string
		this._position = fileInfo.position;
		this.bytesAvailable = fileInfo.filesize!=this._position?fileInfo.filesize - this._position:-1;
		this._eof = (this.bytesAvailable == -1);
	}
}

FileStream.prototype.writeBytes = function writeBytes(byteData){
	var stringResult = HTTP.get('http://localhost:8080/BONDIFilesystem/writeBytes',byteData +';'+this.absolutePath+';'+this.mode+';'+this.encoding);
	if (stringResult == DeviceAPIError.IO_ERROR){
		throw new GenericError(DeviceAPIError.IO_ERROR);
	} else {
		var fileInfo = eval("(" + stringResult + ")"); //JSON string
		this._position = fileInfo.position;
		this.bytesAvailable = fileInfo.filesize!=this._position?fileInfo.filesize - this._position:-1;
		this._eof = (this.bytesAvailable == -1);
	}
}
FileStream.prototype.writeBase64 = function writeBase64(base64data){
	var stringResult = HTTP.get('http://localhost:8080/BONDIFilesystem/writeBase64',base64data +';'+this.absolutePath+';'+this.mode+';'+this.encoding);
	if (stringResult == DeviceAPIError.IO_ERROR){
		throw new GenericError(DeviceAPIError.IO_ERROR);
	} else {
		var fileInfo = eval("(" + stringResult + ")"); //JSON string
		this._position = fileInfo.position;
		this.bytesAvailable = fileInfo.filesize!=this._position?fileInfo.filesize - this._position:-1;
		this._eof = (this.bytesAvailable == -1);
	}
}

PhoneGap.addConstructor(function() {
    if (typeof bondi.filesystem == "undefined") bondi.filesystem = new FileSystemManager();
});


// bondi devicestatus

function DeviceStatusManager() {
    this.BONDIVocabulary = "http://bondi.omtp.org/2010/01/vocabulary"
}

function DeviceStatusError() {
}
DeviceStatusError.READ_ONLY_PROPERTY_ERROR = 1;

DeviceStatusManager.prototype.propertyChangeSuccess = function(property,newValue) {
	this.listener(property,newValue);
}

DeviceStatusManager.prototype.listVocabularies = function() {
	return [this.BONDIVocabulary];
}

DeviceStatusManager.prototype.setDefaultVocabulary = function(vocabulary) {
	if (vocabulary != this.BONDIVocabulary)
		throw new GenericError(DeviceAPIError.NOT_FOUND_ERROR);
}

DeviceStatusManager.prototype.listAspects = function() {
	return ["Battery", "OperatingSystem"];
}

DeviceStatusManager.prototype.getComponents = function(aspect) {
	throw new Error("Not implemented");
}

DeviceStatusManager.prototype.listProperties = function(aspect) {
	if (typeof aspect == "object" && aspect.aspect == "Battery")
		return ["batteryLevel", "batteryTechnology", "batteryBeingCharged"];
	
	if (typeof aspect == "object" && aspect.aspect == "OperatingSystem")
		return ["language", "version", "name", "vendor"];
	
	throw new GenericError(DeviceAPIError.NOT_FOUND_ERROR);
}

DeviceStatusManager.prototype.propertyExists = function(property){
	var aspects = this.listAspects();
	var propertyFound = false;
	for (var i in aspects) {
		var properties = arrayToObjectLiteral(this.listProperties({aspect:aspects[i]}));
		if (property in properties){
			propertyFound = true;
			continue;
		}
	}
	return propertyFound;
}


DeviceStatusManager.prototype.setPropertyValue = function(pref, value) {
	if (typeof pref == "object" && this.propertyExists(pref.property)) //only currentOrientation (Display) is not readonly
		throw new GenericError(DeviceStatusError.READ_ONLY_PROPERTY_ERROR);
	else
		throw new GenericError(DeviceAPIError.NOT_FOUND_ERROR);
}

DeviceStatusManager.prototype.getPropertyValue = function(pref) {
	var returnValue = 'undefined';
	if (typeof pref == "object" && this.propertyExists(pref.property)){
		returnValue =  HTTP.get('http://localhost:8080/BONDIDeviceStatus/getPropertyValue',pref.aspect+";"+ pref.property);
		if (returnValue == DeviceAPIError.INVALID_ARGUMENT_ERROR)
			throw new GenericError(DeviceAPIError.INVALID_ARGUMENT_ERROR);
		else
			return returnValue;
	}	
	throw new GenericError(DeviceAPIError.NOT_FOUND_ERROR);
}

DeviceStatusManager.prototype.watchPropertyChange = function(pref, listener, options) {
	var isBatteryProperty = pref.property in arrayToObjectLiteral(this.listProperties({aspect:"Battery"}));
	if ( !(typeof pref == "object" && isBatteryProperty) ) //only Battery properties can be  watched currently
		throw new GenericError(DeviceAPIError.NOT_FOUND_ERROR);
	bondi.devicestatus.listener = listener;
	var id = HTTP.get('http://localhost:8080/BONDIDeviceStatus/watchPropertyChange',JSON.stringify(pref)+';'+JSON.stringify(options));
    return id;
}
DeviceStatusManager.prototype.clearPropertyChange = function(watchHandler) {
	var stringResult = HTTP.get('http://localhost:8080/BONDIDeviceStatus/clearPropertyChange',watchHandler);
	if (stringResult == DeviceAPIError.INVALID_ARGUMENT_ERROR)
		throw new GenericError(DeviceAPIError.INVALID_ARGUMENT_ERROR);
}

PhoneGap.addConstructor(function() {
	if (typeof bondi.devicestatus == "undefined") bondi.devicestatus = new DeviceStatusManager();
});

