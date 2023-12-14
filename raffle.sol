// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.22;
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "https://github.com/jeongwon0410/raffle/blob/main/dateTime.sol";


contract Raffle is VRFConsumerBaseV2 {

    VRFCoordinatorV2Interface COORDINATOR;

    DateTime public dateTime = new DateTime();
    // 체인링크 구독한 id 토큰빠져나가는 어드민 아이디 설정
    uint64 s_subscriptionId;
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    
    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    bytes32 s_keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;

    // 랜덤값 얻을때 옵션들
    uint32 callbackGasLimit = 40000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 1;

    // 랜덤값 잘 얻어졌는지 테스트용 변수
    uint256 public latestRandomNum = 123456789;
    // 랜던값 요청시 발생하는 이벤트
    event RandomNumberStored(uint256 indexed randomNumber);

    
    //참여자 구조체 -> 참여자:설문조사 = 1:1이라고 생각
    struct application {
        //설문조사 구분 (한명의 참여자는 한개의 서베이만 참여)
        string surveyId;
        //참여자구분
        // string applicationId;
        //참여자이름
        // string name;

        string email;
        //당첨여부
        uint win;
    }

    //설문조사 구조체
    struct survey {
        string surveyId;
        uint raffleTime;
        uint check;
        string[] applicationList;
        string[] winList;
    }

    mapping(string => application) Applications;
    mapping (string => survey) Surveys;
    
    //automate interval 시간
    uint interval = 1;
    //참여자 배열
    string[] applicationArray;
    //survey 배열
    string[] surveyArray;
    
    //survey raffletime 
    // uint[] raffleTime;
    struct raffleTime {
        string[] surveyId;
        uint randomNum;
    }
    
    mapping (uint => raffleTime) RaffleTimes;
    uint public timeStamp;

    //automate test
    uint public count;

    

        // 생성자에 돈빠져나갈 아이디 입력해줘야함 현재 4236
    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_subscriptionId = subscriptionId;
    }

    
    //설문 등록 
    function setSurvey(string memory _surveyId,uint _raffleTime,uint check) public {


        if(keccak256(abi.encodePacked(Surveys[_surveyId].surveyId)) == keccak256(abi.encodePacked(""))){
            // raffleTime.push(_raffleTime);  
            RaffleTimes[_raffleTime].surveyId.push(_surveyId);
            surveyArray.push(_surveyId);
        }
        string[] memory init = new string[](0);
        string[] memory initNum = new string[](0);
        Surveys[_surveyId] = survey(_surveyId,_raffleTime,check,init,initNum);
        
    }

    //설문 가져오기 
    function getSurvey(string memory _surveyId) public view returns (string memory, uint,uint,string[] memory,string[] memory){
        string memory surveyId = Surveys[_surveyId].surveyId;
        uint time = Surveys[_surveyId].raffleTime;
        uint check = Surveys[_surveyId].check;
        string[] memory applicationList = Surveys[_surveyId].applicationList;
        string[] memory winList = Surveys[_surveyId].winList;
        return (surveyId,time,check,applicationList,winList);
    }

    //전체 설문 가져오기
    function getAllSurvey() public view returns(string[] memory){
        return surveyArray;
    }


    //설문 삭제
    function deleteSurvey() public {
        for(uint i =0;i<surveyArray.length;i++){
            delete Surveys[surveyArray[i]];
        }
        // delete raffleTime;
        delete surveyArray;
    }


    //참여자 등록
    function addApplication(string memory _surveyId, string memory _email) public {
        bool flag = false;

      
        for(uint i=0;i<surveyArray.length;i++){
            if(keccak256(abi.encodePacked(surveyArray[i])) == keccak256(abi.encodePacked(_surveyId))){
                if(keccak256(abi.encodePacked(Applications[_email].email)) == keccak256(abi.encodePacked(""))){
                    Surveys[_surveyId].applicationList.push(_email);
                    // Surveys[_surveyId].winList.push(0);
                    applicationArray.push(_email);
                }
                Applications[_email] = application(_surveyId,_email,0);
                flag = true;
            }
        }

        require(flag==true,"add survey");
        
    }



    //참여자 가져오기
    function getApplication(string memory _email) public view returns(string memory, string memory ,uint ){
        string memory email = Applications[_email].email;
        string memory surveyId = Applications[_email].surveyId;
        uint win = Applications[_email].win;
        return (surveyId,email,win);
    }


    //전체 참여자 가져오기
    function getAllAppication() public view returns(string [] memory){
        return applicationArray;
    }

    

    //참여자 삭제
    function deleteApplication() public {
       
        for(uint i=0;i<applicationArray.length;i++){
            delete Applications[applicationArray[i]];
        }
        delete applicationArray;
    }


    function random() public {
        // 체인링크 vrf함수호출 옵션과 함께
        uint256 requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
         // Store the request ID and wait for the callback to store the result
        emit RandomNumberStored(requestId);
    }
    // 체인링크 vrf함수 호출 이후 랜덤값을 받아 동작할 함수
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // 테스트용 변수에 저장
        latestRandomNum = randomWords[0];
        RaffleTimes[timeStamp].randomNum = latestRandomNum;
        emit RandomNumberStored(latestRandomNum);
    }


    //check raffle
    function checkRaffle(string memory _surveyId) public {
        // uint num = 1222;
        uint num = RaffleTimes[Surveys[_surveyId].raffleTime].randomNum;
        if(num == 0){
            num = latestRandomNum;
        } 
        uint index = 0;
        uint i = 0;
        while(index < Surveys[_surveyId].check+i){
            uint idx = num % 10 % Surveys[_surveyId].applicationList.length;
            num = num / 10;
            string memory id = Surveys[_surveyId].applicationList[idx];

            if(Applications[id].win == 1){
                i = i+1;
            }else{
                Surveys[_surveyId].winList.push(Surveys[_surveyId].applicationList[idx]);
                Applications[id].win = 1;
                
            }

            index = index+1;
                    
        }
    
    }


    function getRandomNum(string memory _surveyId) public view returns(uint){
        return RaffleTimes[Surveys[_surveyId].raffleTime].randomNum;
    }

    function getRaffleTime(uint _raffleTime) public view returns(uint){
        return RaffleTimes[_raffleTime].randomNum;
    }


    //automation 
    function checkRandom() public {
        count = count+1;
        uint month = dateTime.getMonth(block.timestamp);
        uint day = dateTime.getDay(block.timestamp);

        for(uint i=0;i<surveyArray.length;i++){
            if(month == dateTime.getMonth(Surveys[surveyArray[i]].raffleTime) && day == dateTime.getDay(Surveys[surveyArray[i]].raffleTime)){
                timeStamp = Surveys[surveyArray[i]].raffleTime;
            
                random();
                // choice();
                
            }
        }
    }
}