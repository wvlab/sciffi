;;
;; cosmo-proto.fnl
;;
;; All messages follow this structure:
;; [1 byte ] Message tag
;; [2 bytes] Message id (unique)
;; [4 bytes] Payload length
;; [n bytes] Payload itself
;;
;; Message Types:
;; handshake:   0x01 - version (2 bytes)
;; response:    0x02 - [1 byte code][n bytes data]
;; getregister: 0x03 - [1 byte type][n bytes name][0x00][k bytes string]
;; putregister: 0x04 - [1 byte type][n bytes name][0x00][k bytes data]
;; write:       0x05 - raw TeX payload
;; log:         0x06 - [1 byte level][0x00][n bytes log message]
;; close:       0x07 - no payload
;;

;;
;;- @enum CosmoProtoMsgType
(local MSG-TYPE {:handshake 0x01
                 :response 0x02
                 :getregister 0x03
                 :putregister 0x04
                 :write 0x05
                 :log 0x06
                 :close 0x07})

;;
;;- @class CosmoProtoHeader
;;- @field messagetag integer
;;- @field messageid integer
;;- @field payloadlen integer
;;

;;
;;- @param bytes string
;;- @return CosmoProtoHeader|{} header
;;- @return string? error
(fn header [bytes]
  "Parses the fixed 7-byte header into a table."
  (if (not= (string.len bytes) 7)
      (values {} "wrong header length")
      (let [(tag id-offset) (string.unpack ">I1" bytes 1)
            (id p-offset) (string.unpack ">I2" bytes id-offset)
            (plen _) (string.unpack ">I4" bytes p-offset)]
        (values {:messagetag tag :messageid id :payloadlen plen} nil))))

;;
;;- @class CosmoProtoPayloadHandshake
;;- @field version integer
;;

;;
;;- @alias CosmoProtoPayload
;;- | CosmoProtoPayloadHandshake
;;- | table -- other message payload types
;;

;; Message Types:
;; handshake:   0x01 - version (2 bytes)
;; response:    0x02 - [1 byte code][n bytes data]
;; getregister: 0x03 - [1 byte type][n bytes name][0x00][k bytes string]
;; putregister: 0x04 - [1 byte type][n bytes name][0x00][k bytes data]
;; write:       0x05 - raw TeX payload
;; log:         0x06 - [1 byte level][0x00][n bytes log message]
;; close:       0x07 - no payload
;;

(fn payload-handshake [bytes]
  (let [(version _) (string.unpack ">I2" bytes)]
    {:tag "handshake" : version}))

(fn payload-response [bytes]
  (let [(code _) (string.unpack ">I1" bytes)
        (data) (string.sub bytes 2)]
    (values {:tag "response" : code : data} nil)))

(fn payload-getregister [bytes]
  (let [(type _) (string.unpack ">I1" bytes)
        rest (string.sub bytes 2)
        (null-pos) (string.find rest "\0")
        name (if null-pos
                 (string.sub rest 1 (- null-pos 1))
                 rest)
        string-data (if null-pos
                        (string.sub rest (+ null-pos 1))
                        "")]
    {:tag "getregister" : type : name :string string-data}))

(fn payload-putregister [bytes]
  (let [(type _) (string.unpack ">I1" bytes)
        rest (string.sub bytes 2)
        (null-pos) (string.find rest "\0")
        name (if null-pos
                 (string.sub rest 1 (- null-pos 1))
                 rest)
        data (if null-pos
                 (string.sub rest (+ null-pos 1))
                 "")]
    {:tag "putregister" : type : name : data}))

(fn payload-log [bytes]
  (let [(level _) (string.unpack ">I1" bytes)
        rest (string.sub bytes 2)
        (null-pos) (string.find rest "\0")
        message (if null-pos
                    (string.sub rest (+ null-pos 1))
                    rest)]
    (values {:tag "log" : level : message} nil)))

(fn payload [header bytes]
  "Parses the payload"
  (if (not= (string.len bytes) header.payloadlen)
      (values {} "wrong payload length")
      (match [header.messagetag]
        [MSG-TYPE.handshake] (values (payload-handshake bytes) nil)
        [MSG-TYPE.response] (values (payload-response bytes) nil)
        [MSG-TYPE.getregister] (values (payload-getregister bytes) nil)
        [MSG-TYPE.putregister] (values (payload-putregister bytes) nil)
        [MSG-TYPE.write] (values {:tag "write" :payload bytes} nil)
        [MSG-TYPE.log] (values (payload-log bytes) nil)
        [MSG-TYPE.close] (values {:tag "close"} nil))))

{: header : payload :MSGTYPE MSG-TYPE}
