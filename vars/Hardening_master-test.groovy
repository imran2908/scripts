/*import org.jenkinsci.plugins.pipeline.modeldefinition.Utils 
import groovy.lang.Binding
import java.lang.*
import groovy.lang.GroovyShell*/


echo "Build_start_time: ${BUILD_TIMESTAMP}"

def Images = params.Image
dockerImage = Images.replace("\n", ",")
echo "Image: ${dockerImage}"
def Hardening_score = params.Threshold
echo "CIS_benchmark Threshold: ${Hardening_score}"

node ('INBLRCYBDTRCHP90') {

    try{
  
        stage('Git Checkout') {   
                          
                git branch: 'development',
                url: 'git@gitlab.apps.ge-healthcare.net:Cyber-Security-Lab/common-lib-devops.git',
                credentialsId: 'hardening_90'       
            }
        /*stage ('shellcheck') {
                    catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
                    sh """
					pwd
                    id
					shellcheck --color=never --severity=error ./resources/*.sh > shellcheck.log
					
					"""
                }
            }*/
    
            
        stage ('Twistcli Initial Scan') {
	    withCredentials([usernamePassword(credentialsId: 'prisma_cred_for_DTR', passwordVariable: 'twistlock_pass', usernameVariable: 'twistlock_user')]) {
                
        sh '''
					pwd
                    id
					cd ./resources
					chmod a+x ./new_twistcli_initial_scan_copy.sh && sudo bash ./new_twistcli_initial_scan_copy.sh $Image $twistlock_user $twistlock_pass
					
					'''
                    
        }
                emailext attachLog: false,
                attachmentsPattern:'resources/Initial_TwistlockOutput1.log',
            	to: "503357954@gehealthcare.com",
                subject: "[${env.BUILD_NUMBER}] Container Hardening Pipeline | Pre-Harden TWISTLOCK SCAN REPORT | ${Image}",
				body: 
				    '''
				    </b></p>Job_name: ${JOB_NAME} </p></b>
				    </b></p>Build_number: ${BUILD_NUMBER} </p></b>
                    </b></p>Build_timestamp: ${BUILD_TIMESTAMP} </p></b>
                    <br>
                    
                    </p><b>===========================================================================================================================================</b></p><br>

                    ${BUILD_LOG_REGEX, regex=".*(Started.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Job $1"}
                    ${BUILD_LOG_REGEX, regex=".*(Image:.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}
                    ${BUILD_LOG_REGEX, regex=".*(BaseImage_OS.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}
                    ${BUILD_LOG_REGEX, regex=".*(CIS_benchmark.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}                    
                    <br>  

                    <p></b>Pre-Harden Twistlock Scan Report </b></p>
                    </b></p>${BUILD_LOG_REGEX, regex=".*(Vulnerabilities found.*low - [0-9]*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</b></p>
                    </b></p>${BUILD_LOG_REGEX, regex=".*(Compliance found.*low - [0-9]*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</b></p><br>

                    <b></p>Pre-Harden CIS Benchmarks Score</p></b>
                    </b></p>${BUILD_LOG_REGEX, regex=".*Checks:( [0-9]*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Checks: $1"}</b></p>
                    </b></p>${BUILD_LOG_REGEX, regex=".*Score:(.*)", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Score: $1"}</b></p>
                    </b></p>${BUILD_LOG_REGEX, regex=".*Percentage Compliance: (.*)", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Percentage Compliance: $1"}</b></p><br>

                    </p><b>===========================================================================================================================================</b></p><br>

                    <p>Regards,<br>DTR Core Team</p><br>
         
                    '''

        }

      /*  stage('Base-Image Staging Artifactory Push') {
                docker.withRegistry('https://blr-artifactory.cloud.health.ge.com/docker-cyberlab-stage', '503302923_Jfrog_RT') { 
                sh '''
					        pwd
                            id
					        cd ./resources
					        chmod a+x ./new_BaseImage_Push_copy.sh && ./new_BaseImage_Push_copy.sh $Image 
                    ''' 
                }    
            }  */

        stage ('OCI Check') {
                sh '''
					pwd
                    id
					cd ./resources
					chmod a+x ./new_OCIcheck.sh && ./new_OCIcheck.sh $Image > ${WORKSPACE}/ocicheck.txt
					
					'''
                    script {                        
                        //env.myVar = sh(script: "set +x && cat ${WORKSPACE}/ocicheck.txt | tail -1",returnStdout: true).trim()
                        env.myVar = sh(
                                        script: """
                                        set +x
                                        cat ${WORKSPACE}/ocicheck.txt | \
                                        tail -1
                                        """,
                                        returnStdout: true
                                    ).trim()
                        echo "${env.myVar}"
                    }
                    }
                    if (env.myVar == 'success'){
                        
                        stage ('Docker Bench Check') {
	                
                            sh '''
					        pwd
                            id
					        cd ./resources
					        chmod a+x ./new_dockerbench_initial_scan.sh && sudo bash ./new_dockerbench_initial_scan.sh $Image 
                            '''     

                        }

//start of Hardening script
             script {                    
                    //env.BaseImage_OS = sh( script: "docker run --rm -a stdout --entrypoint cat $Image  '/etc/os-release' | grep -i pretty_name | cut -d = -f 2",returnStdout: true).trim()
                    env.BaseImage_OS =  sh(
                                            script: """
                                            set +x
                                            docker run --rm -a stdout --entrypoint cat $Image  '/etc/os-release' | \
                                            grep -i pretty_name | \
                                            cut -d = -f 2
                                            """,
                                            returnStdout: true
                                        ).trim()
                    //echo "BaseImage_OS: ${env.BaseImage_OS}"
                }

            if (env.BaseImage_OS.contains('Alpine') == true){
                //echo "You are inside Alpine if condition"
                stage (' Image Hardening ') {
                    sh '''
					        pwd
                            id
					        cd ./resources
					        chmod a+x ./new_t1bash_copy.sh && sudo bash ./new_t1bash_copy.sh $Image 
                            ''' 
                }
                }
            else if (env.BaseImage_OS.contains('Debian') == true || env.BaseImage_OS.contains('Ubuntu') == true){
                stage (' Image Hardening ') {
                    sh '''
					        pwd
                            id
					        cd ./resources
					        chmod a+x ./new_t1ubuntu_copy.sh && sudo bash ./new_t1ubuntu_copy.sh $Image 
                            ''' 
                }
            }
            else if (env.BaseImage_OS.contains('CentOS') == true){
                stage (' Image Hardening ') {
                    sh '''
					        pwd
                            id
					        cd ./resources
					        chmod a+x ./new_t1centos_copy.sh && sudo bash ./new_t1centos_copy.sh $Image 
                            ''' 
                }
            }
            else if (env.BaseImage_OS.contains('SUSE') == true){
                stage (' Image Hardening ') {
                    sh '''
					        pwd
                            id
					        cd ./resources
					        chmod a+x ./new_t1suse_copy.sh && sudo bash ./new_t1suse_copy.sh $Image 
                            ''' 
                }
            }
            else{
                    stage (' Image Hardening ') {
                    sh '''
					        pwd
                            id
					        cd ./resources
					        chmod a+x ./new_t1nonos.sh && sudo bash ./new_t1nonos.sh $Image 
                            ''' 
                }
                }
//End of Hardening script

        stage ('Twistcli Post Hardening Scan') {            
	            withCredentials([usernamePassword(credentialsId: 'prisma_cred_for_DTR', passwordVariable: 'twistlock_pass', usernameVariable: 'twistlock_user')]) {
                
        sh '''
					pwd
                    id
					cd ./resources
					chmod a+x ./new_Posttwistlockscan_copy.sh && sudo bash ./new_Posttwistlockscan_copy.sh $Image $twistlock_user $twistlock_pass
					
					'''
                    
        }
            
//Start of Twistlock critical High check script
                    script {                        
                        env.Expected_CRITICAL = 0
                        env.Expected_HIGH = 0
                        //env.Twistlock_CRITICAL = sh( script: "cat resources/Post_TwistlockOutput2.log | grep -m1 'Vulnerabilities ' | awk -F, '{print  \$2}' | awk -F '- ' '{print \$NF}'",returnStdout: true).trim()
                        env.Twistlock_CRITICAL = sh(
                                                    script: """
                                                    set +x
                                                    cat resources/Post_TwistlockOutput2.log | \
                                                    grep -m1 'Vulnerabilities ' | \
                                                    awk -F, '{print  \$2}' | \
                                                    awk -F '- ' '{print \$NF}'
                                                    """,
                                                    returnStdout: true
                                                ).trim()
                        //env.Twistlock_HIGH = sh( script: "cat resources/Post_TwistlockOutput2.log | grep -m1 'Vulnerabilities ' | awk -F, '{print  \$3}' | awk -F '- ' '{print \$NF}'",returnStdout: true).trim()
                        env.Twistlock_HIGH = sh(
                                                script: """
                                                set +x
                                                cat resources/Post_TwistlockOutput2.log | \
                                                grep -m1 'Vulnerabilities ' | \
                                                awk -F, '{print  \$3}' | \
                                                awk -F '- ' '{print \$NF}'
                                                """,
                                                returnStdout: true
                                            ).trim()
                        echo "Twistlock_CRITICAL : ${env.Twistlock_CRITICAL}"
                        echo "Twistlock_HIGH : ${env.Twistlock_HIGH}"
                    }
                    }                    
                    if (env.Twistlock_CRITICAL == env.Expected_CRITICAL && env.Twistlock_HIGH == env.Expected_HIGH){
                               
                        echo "Twistlock scan PASSED"
                    
                                                                 
            
//End of Twistlock critical check script     

        stage ('Docker Bench Score Validation') {
                sh '''
					        pwd
                            id
					        cd ./resources
					        chmod a+x ./new_CIS_validation_copy.sh && sudo bash ./new_CIS_validation_copy.sh $Image $Threshold
                    '''
 }
//Start of Docker Bench score check script                 
                script {                        
                        env.Threshold_CISScore = "${Hardening_score}"
                        echo "Threshold_CISScore : ${env.Threshold_CISScore}"
                        //env.Achieved_CISScore = sh( script: "cat docker-bench/docker-bench-security-1.5.0/DockerBenchOutput2.log | grep -i Score: | awk {'print \$3'}",returnStdout: true).trim()
                        env.Achieved_CISScore = sh(
                                                    script: """
                                                    set +x
                                                    cat docker-bench/docker-bench-security-1.5.0/DockerBenchOutput2.log | \
                                                    grep -i Score: | \
                                                    awk {'print \$3'}
                                                    """,
                                                    returnStdout: true
                                                ).trim()
                        echo "Achieved_CISScore : ${env.Achieved_CISScore}"
                    }
                    if (env.Achieved_CISScore >= env.Threshold_CISScore){    
                        echo "SUCCESS - Docker Bench Threshold Score Achieved!!"                   
                    
//End of Docker Bench score check script

//Start of Notification Script            

                    stage ('Notify Approver') {
                        emailext attachLog: true,
                        attachmentsPattern:'docker-bench/docker-bench-security-1.5.0/DockerBenchOutput1.log,resources/secret.txt,resources/Initial_TwistlockOutput1.log,resources/Post_TwistlockOutput2.log,docker-bench/docker-bench-security-1.5.0/DockerBenchOutput2.log,shellcheck.log',
            	        to: "503357954@gehealthcare.com",
            	        subject: "[${env.BUILD_NUMBER}] Container Hardening Pipeline | Approval Request | ${Image}",
				        body: 
                        '''
                        </b></p>Job_name: ${JOB_NAME} </p></b>
				        </b></p>Build_number: ${BUILD_NUMBER} </p></b>
                        </b></p>Build_timestamp: ${BUILD_TIMESTAMP} </p></b>
                        <br>
                        </p><b>+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++</b></p><br>
                                                                        
                        ${BUILD_LOG_REGEX, regex=".*(Started.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Job $1"}
                        ${BUILD_LOG_REGEX, regex=".*(Image:.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}
                        ${BUILD_LOG_REGEX, regex=".*(BaseImage_OS.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}
                        ${BUILD_LOG_REGEX, regex=".*(CIS_benchmark.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}                        
                        <br>                                       
                                                
                        <b></p>Pre-Harden Twistlock Scan Report </p></b>
                        </p>${BUILD_LOG_REGEX, regex=".*(Vulnerabilities found.*low - [0-9]*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p>
                        </p>${BUILD_LOG_REGEX, regex=".*(Compliance found.*low - [0-9]*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br>
                        
                        <b></p>Post-Harden Twistlock Scan Report</p></b>
                        </p>${BUILD_LOG_REGEX, regex="(?=.*?Vulnerabilities found .*)(^((?!${Image}:).)*$)", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p>
                        </p>${BUILD_LOG_REGEX, regex="(?=.*?Compliance found .*)(^((?!${Image}:).)*$)", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br>                               
                             
                        <b></p>Pre-Harden CIS Benchmarks Score</p></b>
                        </b></p>${BUILD_LOG_REGEX, regex=".*Checks:( [0-9]*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Checks: $1"}</b></p>
                        </b></p>${BUILD_LOG_REGEX, regex=".*Score:(.*)", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Score: $1"}</b></p>
                        </b></p>${BUILD_LOG_REGEX, regex=".*Percentage Compliance: (.*)", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Percentage Compliance: $1"}</b></p><br>

                        <b></p>Post-Harden CIS Benchmarks Score</p></b>
                        </b></p>${BUILD_LOG_REGEX, regex=".*check=(.*)", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Checks: $1"}</p>
                        </b></p>${BUILD_LOG_REGEX, regex=".*score=(.*)", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Score: $1"}</p>               
                        </b></p>${BUILD_LOG_REGEX, regex=".*Percentage Compliance= (.*)", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="Percentage Compliance: $1"}</b></p><br>
                        </p><b>+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++</b></p><br>
                        
                        <table style="border: 1px solid #000000;"> 
                        <b></p>Please click <a href="${BUILD_URL}/input/">here</a> to either Approve or Deny Golden Image push to blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/  </p></b>
                        </table>
                        <br>

                        <p>Regards,<br>DTR Core Team</p><br>

                        '''
                    }
                    

try {
    stage('Deploy Approval') {
                        timeout(time:180, unit:'MINUTES') {                            
                            script {
                                def userInput1 = input(id: 'userInput1', message: 'Your input is mandatory to push Golden Image to Artifactory', ok: 'Confirm Selection',  submitter: '503357954,503314392,503357952,503335120', parameters: [[$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Please left-click once on the checkbox above to put a check mark and hit Confirm button below to invoke artifactory push. Otherwise hit Abort.', name: 'Push Golden Image to blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/']])
            //echo 'userInput: ' + userInput1
            println(userInput1)
                        
                        if (userInput1 == true){
                            //echo "========== Golden Image to be Pushed Dev Artifactory =============="
							                           
                            stage('Golden Image Push to Artifactory') {
                                docker.withRegistry('https://blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev', '503302923_Jfrog_RT') {
                                sh '''
					            pwd
                                id
					            cd ./resources
					            chmod a+x ./new_HardenImage_Push_copy-test.sh && sudo bash ./new_HardenImage_Push_copy-test.sh $Image
                                '''
                            }
                            }                            
                            
							emailext attachLog: true,
                            attachmentsPattern:'',
                            to: "503357954@gehealthcare.com",
                            subject: "[${env.BUILD_NUMBER}] Container Hardening Pipeline: Status | ${Image}",
                            body: 
                            '''
                            </b></p>Job_name: ${JOB_NAME} </p></b>
				            </b></p>Build_number: ${BUILD_NUMBER} </p></b>
                            </b></p>Build_timestamp: ${BUILD_TIMESTAMP} </p></b>
                            </b></p>Build_status: ${BUILD_STATUS} </p></b>
                                                     
                            </p></b>${BUILD_LOG_REGEX, regex="COMMENTS.*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true}</b></p>
				            </b></p>${BUILD_LOG_REGEX, regex=".*(Approved by .*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</b></p><br>
                            </b></p>Harden image ${Image} successfully pushed to artifactory. Path to download as follows:</b></p><br>
                            <table style="border: 1px solid #000000;"> 
                            </b></p>${BUILD_LOG_REGEX, regex=".*( blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p></b>
                            </table><br>
                            
				            <p>Regards,<br>DTR Core Team</p><br>
                            '''
                        }
                        else{
                          catchError(buildResult: 'FAILURE', stageResult: 'ABORTED') 
                            {		
                                
                                script{
                                def userInput2 = input(id: 'userInput2', message: 'Are we sure do not want to push Golden Image to Artifactory?', ok: 'Confirm',  submitter: '503357954,503314392,503357952', parameters: [[$class: 'TextParameterDefinition', defaultValue: '', description: 'Please add remarks in the textbox below before hitting Confirm button below. Otherwise hit Abort.', name: 'Remarks']])
            //echo 'userInput: ' + userInput2
            println(userInput2)
                                }                             
                            }
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

 
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////          
                            stage ('Cleanup') {
                    sh '''
					        echo "1 cleanup"
                            pwd
                            id
					        cd ./resources					        
                            chmod a+x ./new_cleanup_copy_2.sh && sudo bash ./new_cleanup_copy_2.sh $Image 
                                                    
                            
                            ''' 
                            cleanWs()
                            dir("${WORKSPACE}@tmp") {
                                deleteDir()
                                }
                            }   
                        }
//////////////.......................................................................................//////////////////
          stage ('Twistcli Scan') {

              //env.HardenImage= sh 'cat ./resources/image-name.txt'
                  //def  HardenImage= sh 'cat ./resources/image-name.txt'
                  def HardenImage= readFile './resources/image-name.txt'
                  env.HardenImage1=HardenImage
                  println(HardenImage)
                withCredentials([usernamePassword(credentialsId: 'prisma_cred_for_DTR', passwordVariable: 'twistlock_pass', usernameVariable: 'twistlock_user')]) {
                ///sh 'sudo bash /root/Hardening-Team-Development/Release-SingleImage/TwistcliScan_Release.sh $twistlock_user $twistlock_pass'  
                sh 'sudo bash ./resources/TwistcliScan_Release.sh $(cat ./resources/image-name.txt) $twistlock_user $twistlock_pass'
                }
                script {
                    env.Expected_CRITICAL = 0
                    env.Expected_HIGH = 0
                    env.Twistlock_CRITICAL = sh( script: "set +x && cat Release_TwistlockOutput3.log | grep -m1 'Vulnerabilities ' | awk -F, '{print  \$2}' | awk -F '- ' '{print \$NF}'",returnStdout: true).trim()
                    env.Twistlock_HIGH = sh( script: "set +x && cat Release_TwistlockOutput3.log | grep -m1 'Vulnerabilities ' | awk -F, '{print  \$3}' | awk -F '- ' '{print \$NF}'",returnStdout: true).trim()
                    echo "Twistlock_CRITICAL : ${env.Twistlock_CRITICAL}"
                    echo "Twistlock_HIGH : ${env.Twistlock_HIGH}"
                     
                    String[] split_Image = HardenImage.split('/')
                    String[] split_Image_First = split_Image[2].split('_harden')
                    env.Image_First = split_Image_First[0]

                    
                }
                if (env.Twistlock_CRITICAL == env.Expected_CRITICAL && env.Twistlock_HIGH == env.Expected_HIGH){
                    
                    stage('Notify Approver'){
                            echo 'Release Twistlock Scan Pass. Approval Mail to be Triggered *****'                              
                            emailext attachLog: true,
                            attachmentsPattern:'Release_TwistlockOutput3.*',

                            to: "503357954@gehealthcare.com,cc:503357954@gehealthcare.com",
                            subject: "[${env.BUILD_NUMBER}] Release Pipeline | Approval Request | ${env.Image_First} ",
                            body: 
                                '''
                                </b></p>Job_name=${JOB_NAME}, 
                                </b></p>Build_number=${BUILD_NUMBER},
                                </b></p>Build_timestamp=${BUILD_TIMESTAMP},
                                
                                <table style="border: 1px solid #000000;"> 
                                    <tr><th>HardenImage at Dev</th><td style="border: 1px solid #000000;"> ${FILE, path="./resources/image-name.txt"}</td></tr>
                                </table>
                                <br>
                                </p><b>Post Harden Twistlock Scan</b></p>
                                </p><b>================================================================================================================</b></p>
                               
                                </p>${BUILD_LOG_REGEX, regex=".*(Vulnerabilities found.*_harden_.*low - [0-9]*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p>
                               </p>${BUILD_LOG_REGEX, regex="(Compliance found.*_harden_.*low - [0-9]*)", linesBefore=0, linesAfter=0, maxMatches=3, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br> 

                                 </p><b>================================================================================================================</b></p>  
                                    
                                <b></p>Click <a href="${BUILD_URL}/input/">${JOB_NAME}:${BUILD_NUMBER}</a> to Approve/Deny Harden Image push to Release Artifactory </p></b>
                                <br>
                                </p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p>

                                <p>Regards,<br>DTR Core Team</p>
                                    
                            
                               '''
                    }
                    stage('Deploy approval') {
                            timeout(time:5, unit:'HOURS') {
                                script{
                                //env.PUSH_IMG = input message: 'Push Image to Release Dev Artifact', ok: 'Continue',
                                //parameters: [extendedChoice(name: 'Push_to_Release', type: 'Check Boxes', value: ''+HardenImage+''),choice(name: 'Push_Artifact',choices: 'YES\nNO', description: 'push to artifact')]
                                //parameters: [choice(name: 'Push_to_Release',choices: 'YES\nNO', description: "HardenImage in Dev: '+HardenImage+'")]
                                //echo "${env.PUSH_IMG}"
                                def userInput3 = input(id: 'userInput1', message: 'Your input is mandatory to push Golden Image to Artifactory', ok: 'Confirm Selection', parameters: [[$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Please left-click once on the checkbox above to put a check mark and hit Confirm button below to invoke artifactory push. Otherwise hit Abort.', name: 'Push Golden Image to blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-release/']])
            
            //echo 'userInput: ' + userInput1
            println(userInput3)
                            
                            //if (env.PUSH_IMG == 'YES')
                            if (userInput3 == true){
                                echo "========== Harden Image to be Pushed to Release Artifactory =============="
                                docker.withRegistry('https://blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev', '503302923_Jfrog_RT') {
                                   /// sh 'sudo bash /root/Hardening-Team-Development/Release-SingleImage/ReleasePush_reboot.sh $HardenImage'
                                 sh 'chmod a+x ./resources/ReleasePush_reboot.sh && sudo bash ./resources/ReleasePush_reboot.sh '+HardenImage+''  
                                                                       
                                }
                                    
                                    
                                emailext attachLog: false,attachmentsPattern:'Release_TwistlockOutput3.*,DTR_comms_new_header.png,cyblab.png',
                                to: "503357954@gehealthcare.com",
                                subject: "[${env.BUILD_NUMBER}] DTR Release Info | Harden Docker Image '${env.Image_First}' Pushed to DTR",
                                body: 
                                '''
                                    <table style="border: 1px solid #000000;">
                                    
                                    <img src = "DTR_comms_new_header.png" alt = "GE Image" style="width: 100%" />
                                    <p align = "center"><b>Docker Trust Registry (DTR) Communication</b></p>
                                    <br><p>Hello Everyone,</p>  
                                                                                          
                                    <p>Harden Image pushed to Release repo. Path to download artifact as follows:</p>
                                    <table style="border: 1px solid #000000;">
                                    <p>${BUILD_LOG_REGEX, regex=".*(ReleaseImage =.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br>
                                    <p>${BUILD_LOG_REGEX, regex=".*(ImageSize =.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br>
                                    <p>${BUILD_LOG_REGEX, regex=".*(VulCount =.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br></table>
                                                                        
                                    <br><b>DTR Confluence:</b> https://ge-hc.atlassian.net/wiki/spaces/CZJTA/pages/110235083/GEHC+Docker+Trust+Registry+DTR<br>
                               	<br><b>Release Image List:</b> https://ge-hc.atlassian.net/wiki/spaces/CZJTA/pages/110235215/DTR+Images<br>
                               	<br><b>New Image request:</b> https://app.sc.ge.com/workflows/initiate/729412<br>
                               	<br><p><b>Get yourself added to DTR DL:</b> https://ge-hc.atlassian.net/wiki/spaces/CZJTA/pages/110235083/GEHC+Docker+Trust+Registry+DTR#6.-Email-notifications-and-links</p><br>

                                    <br></p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p><br>

                                    <p>Regards,<br>DTR Core Team</p>
                                    <img src = "cyblab.png" alt = "Test Image" width = "150" height = "100" />
                                    </table>

                                                                    
                                '''
                            }
                            else{
                            catchError(buildResult: 'Success', stageResult: 'ABORTED', message : 'Job has been timeout') 
                                {
                    
                                    env.COMMENTS = input message: 'Decline : Push Image to Release Dev Artifact',
                                    parameters: [string(defaultValue: '', name: 'Reason')]
                                    echo "COMMENTS: ${env.COMMENTS}"
                                }
                                echo "COMMENTS: ${env.COMMENTS}"
                                docker.withRegistry('https://blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev', '503302923_Jfrog_RT') {
                                        sh 'docker tag "'+HardenImage+'" blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseApprovalDenied'
                                        sh 'docker push blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseApprovalDenied'
                                        sh 'docker rmi -f blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseApprovalDenied'
                                }
                                emailext attachLog: true,attachmentsPattern:'Release_TwistlockOutput3.*',
                                to: "503357954@gehealthcare.com",
                                subject: "Status: ${currentBuild.result?:'Approval Declined'} - Job \'${env.JOB_NAME}:${env.BUILD_NUMBER}\'",
                                body: 
                                    '''
                                    </p>Job_name=${JOB_NAME}, 
                                    </b></p>Build_number=${BUILD_NUMBER},
                                    </b></p>Build_timestamp=${BUILD_TIMESTAMP},
                                
                                    <table style="border: 1px solid #000000;"> 
                                        <tr><th>HardenImage at Dev Repo</th><td style="border: 1px solid #000000;"> '+HardenImage+'</td></tr>
                                        
                                    </table>                     
                                    
                                    <p>${BUILD_LOG_REGEX, regex=".*("COMMENTS.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p>
                                    <br>
                                    </p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p>

                                    <p>Regards,<br>DTR Core Team</p>
                                    
                                    '''
                            }
                            }
                            }
                    }
                }
                else{
                    echo "Twistlock scan Failed!"
                    docker.withRegistry('https://blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev', '503302923_Jfrog_RT') {
                                    sh 'docker tag "'+HardenImage+'" blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseTwistlockFailed'
                                    sh 'docker push blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseTwistlockFailed'
                                    sh 'docker rmi -f blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseTwistlockFailed'
                                }
                    emailext attachLog: true,
                            attachmentsPattern:'Release_TwistlockOutput3.*',

                            to: "503357954@gehealthcare.com",
                            subject: "Release Pipeline |Twistlock Checkpoint Failed|${env.Image_First}",
                            body: 
                            '''
                            
                            </b></p>Job_name=${JOB_NAME}, 
                            </b></p>Build_number=${BUILD_NUMBER}, 
                            </b></p>Build_timestamp=${BUILD_TIMESTAMP},
                                
                                    <table style="border: 1px solid #000000;"> 
                                        <tr><th>HardenImage at Dev Repo</th><td style="border: 1px solid #000000;"> '+HardenImage+'</td></tr>
                                        
                                    </table>
                            <br>
                            </p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p>

                            <p>Regards,<br>DTR Core Team</p>
                            '''

                }
            }


///////////////////...................................................................................//////////////////////////
                    }
                }
            }
}
catch (error) {
            stage ('Cleanup') {
                    sh '''
					        echo "2 cleanup"
                            pwd
                            id
					        cd ./resources					        
                            chmod a+x ./new_cleanup_copy_2.sh && sudo bash ./new_cleanup_copy_2.sh $Image 
                                                    
                            
                            ''' 
                            cleanWs()
                            dir("${WORKSPACE}@tmp") {
                                deleteDir()
                            }
                }
}                    
                    
                    }
                    else{                        
                            echo "FAILURE - Docker Bench Threshold Score NOT Achieved!!"
                            echo "Subsequent Stages to be Skipped"
                            currentBuild.result = 'FAILURE'
                    }
                }
                    else{                                           
                            echo "Twistlock scan FAILED - Golden Image have ${env.Twistlock_CRITICAL} Critical ${env.Twistlock_HIGH} High Vulnerabilities"
                            echo "Subsequent Stages to be Skipped"
                            currentBuild.result = 'FAILURE'          
                        
                    }
                    }
                    else {
                        echo "Restricted applied on $Image hence cannot be hardened"
////////////&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&////

                                  stage ('Twistcli Scan') {

              //env.HardenImage= sh 'cat ./resources/image-name.txt'
                  //def  HardenImage= sh 'cat ./resources/image-name.txt'

        sh '''
					            pwd
                                id
					            cd ./resources
					            chmod a+x ./new_HardenImage_Push_copy-test-oci.sh && sudo bash ./new_HardenImage_Push_copy-test-oci.sh $Image
                                '''

                  def HardenImage= readFile './resources/image-name.txt'
                 
                  env.HardenImage1=HardenImage
                  println(HardenImage)
                withCredentials([usernamePassword(credentialsId: 'prisma_cred_for_DTR', passwordVariable: 'twistlock_pass', usernameVariable: 'twistlock_user')]) {
                ///sh 'sudo bash /root/Hardening-Team-Development/Release-SingleImage/TwistcliScan_Release.sh $twistlock_user $twistlock_pass'  
                sh 'sudo bash ./resources/TwistcliScan_Release.sh $(cat ./resources/image-name.txt) $twistlock_user $twistlock_pass'
                }
                script {
                    env.Expected_CRITICAL = 0
                    env.Expected_HIGH = 0
                    env.Twistlock_CRITICAL = sh( script: "set +x && cat Release_TwistlockOutput3.log | grep -m1 'Vulnerabilities ' | awk -F, '{print  \$2}' | awk -F '- ' '{print \$NF}'",returnStdout: true).trim()
                    env.Twistlock_HIGH = sh( script: "set +x && cat Release_TwistlockOutput3.log | grep -m1 'Vulnerabilities ' | awk -F, '{print  \$3}' | awk -F '- ' '{print \$NF}'",returnStdout: true).trim()
                    echo "Twistlock_CRITICAL : ${env.Twistlock_CRITICAL}"
                    echo "Twistlock_HIGH : ${env.Twistlock_HIGH}"
                     
                    String[] split_Image = HardenImage.split('/')
                    String[] split_Image_First = split_Image[2].split('_harden')
                    env.Image_First = split_Image_First[0]

                    
                }
                if (env.Twistlock_CRITICAL == env.Expected_CRITICAL && env.Twistlock_HIGH == env.Expected_HIGH){
                    
                    stage('Notify Approver'){
                            echo 'Release Twistlock Scan Pass. Approval Mail to be Triggered *****'                              
                            emailext attachLog: true,
                            attachmentsPattern:'Release_TwistlockOutput3.*',

                            to: "503357954@gehealthcare.com,cc:503357954@gehealthcare.com",
                            subject: "[${env.BUILD_NUMBER}] Release Pipeline | Approval Request | ${env.Image_First} ",
                            body: 
                                '''
                                </b></p>Job_name=${JOB_NAME}, 
                                </b></p>Build_number=${BUILD_NUMBER},
                                </b></p>Build_timestamp=${BUILD_TIMESTAMP},
                                
                                <table style="border: 1px solid #000000;"> 
                                    <tr><th>HardenImage at Dev</th><td style="border: 1px solid #000000;"> ${FILE, path="./resources/image-name.txt"}</td></tr>
                                </table>
                                <br>
                                </p><b>Post Harden Twistlock Scan</b></p>
                                </p><b>================================================================================================================</b></p>
                               
                                </p>${BUILD_LOG_REGEX, regex=".*(Vulnerabilities found.*_harden_.*low - [0-9]*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p>
                               </p>${BUILD_LOG_REGEX, regex="(Compliance found.*_harden_.*low - [0-9]*)", linesBefore=0, linesAfter=0, maxMatches=3, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br> 

                                 </p><b>================================================================================================================</b></p>  
                                    
                                <b></p>Click <a href="${BUILD_URL}/input/">${JOB_NAME}:${BUILD_NUMBER}</a> to Approve/Deny Harden Image push to Release Artifactory </p></b>
                                <br>
                                </p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p>

                                <p>Regards,<br>DTR Core Team</p>
                                    
                            
                               '''
                    }
                    stage('Deploy approval') {
                            timeout(time:5, unit:'HOURS') {
                                script{
                                //env.PUSH_IMG = input message: 'Push Image to Release Dev Artifact', ok: 'Continue',
                                //parameters: [extendedChoice(name: 'Push_to_Release', type: 'Check Boxes', value: ''+HardenImage+''),choice(name: 'Push_Artifact',choices: 'YES\nNO', description: 'push to artifact')]
                                //parameters: [choice(name: 'Push_to_Release',choices: 'YES\nNO', description: "HardenImage in Dev: '+HardenImage+'")]
                                //echo "${env.PUSH_IMG}"
                                def userInput3 = input(id: 'userInput1', message: 'Your input is mandatory to push Golden Image to Artifactory', ok: 'Confirm Selection', parameters: [[$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Please left-click once on the checkbox above to put a check mark and hit Confirm button below to invoke artifactory push. Otherwise hit Abort.', name: 'Push Golden Image to blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-release/']])
            
            //echo 'userInput: ' + userInput1
            println(userInput3)
                            
                            //if (env.PUSH_IMG == 'YES')
                            if (userInput3 == true){
                                echo "========== Harden Image to be Pushed to Release Artifactory =============="
                                docker.withRegistry('https://blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev', '503302923_Jfrog_RT') {
                                   /// sh 'sudo bash /root/Hardening-Team-Development/Release-SingleImage/ReleasePush_reboot.sh $HardenImage'
                                 sh 'chmod a+x ./resources/ReleasePush_reboot.sh && sudo bash ./resources/ReleasePush_reboot.sh '+HardenImage+''  
                                                                       
                                }
                                    
                                    
                                emailext attachLog: false,attachmentsPattern:'Release_TwistlockOutput3.*,DTR_comms_new_header.png,cyblab.png',
                                to: "503357954@gehealthcare.com",
                                subject: "[${env.BUILD_NUMBER}] DTR Release Info | Harden Docker Image '${env.Image_First}' Pushed to DTR",
                                body: 
                                '''
                                    <table style="border: 1px solid #000000;">
                                    
                                    <img src = "DTR_comms_new_header.png" alt = "GE Image" style="width: 100%" />
                                    <p align = "center"><b>Docker Trust Registry (DTR) Communication</b></p>
                                    <br><p>Hello Everyone,</p>  
                                                                                          
                                    <p>Harden Image pushed to Release repo. Path to download artifact as follows:</p>
                                    <table style="border: 1px solid #000000;">
                                    <p>${BUILD_LOG_REGEX, regex=".*(ReleaseImage =.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br>
                                    <p>${BUILD_LOG_REGEX, regex=".*(ImageSize =.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br>
                                    <p>${BUILD_LOG_REGEX, regex=".*(VulCount =.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br></table>
                                                                        
                                    <br><b>DTR Confluence:</b> https://ge-hc.atlassian.net/wiki/spaces/CZJTA/pages/110235083/GEHC+Docker+Trust+Registry+DTR<br>
                               	<br><b>Release Image List:</b> https://ge-hc.atlassian.net/wiki/spaces/CZJTA/pages/110235215/DTR+Images<br>
                               	<br><b>New Image request:</b> https://app.sc.ge.com/workflows/initiate/729412<br>
                               	<br><p><b>Get yourself added to DTR DL:</b> https://ge-hc.atlassian.net/wiki/spaces/CZJTA/pages/110235083/GEHC+Docker+Trust+Registry+DTR#6.-Email-notifications-and-links</p><br>

                                    <br></p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p><br>

                                    <p>Regards,<br>DTR Core Team</p>
                                    <img src = "cyblab.png" alt = "Test Image" width = "150" height = "100" />
                                    </table>

                                                                    
                                '''
                            }
                            else{
                            catchError(buildResult: 'Success', stageResult: 'ABORTED', message : 'Job has been timeout') 
                                {
                    
                                    env.COMMENTS = input message: 'Decline : Push Image to Release Dev Artifact',
                                    parameters: [string(defaultValue: '', name: 'Reason')]
                                    echo "COMMENTS: ${env.COMMENTS}"
                                }
                                echo "COMMENTS: ${env.COMMENTS}"
                                docker.withRegistry('https://blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev', '503302923_Jfrog_RT') {
                                        sh 'docker tag "'+HardenImage+'" blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseApprovalDenied'
                                        sh 'docker push blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseApprovalDenied'
                                        sh 'docker rmi -f blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseApprovalDenied'
                                }
                                emailext attachLog: true,attachmentsPattern:'Release_TwistlockOutput3.*',
                                to: "503357954@gehealthcare.com",
                                subject: "Status: ${currentBuild.result?:'Approval Declined'} - Job \'${env.JOB_NAME}:${env.BUILD_NUMBER}\'",
                                body: 
                                    '''
                                    </p>Job_name=${JOB_NAME}, 
                                    </b></p>Build_number=${BUILD_NUMBER},
                                    </b></p>Build_timestamp=${BUILD_TIMESTAMP},
                                
                                    <table style="border: 1px solid #000000;"> 
                                        <tr><th>HardenImage at Dev Repo</th><td style="border: 1px solid #000000;"> '+HardenImage+'</td></tr>
                                        
                                    </table>                     
                                    
                                    <p>${BUILD_LOG_REGEX, regex=".*("COMMENTS.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p>
                                    <br>
                                    </p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p>

                                    <p>Regards,<br>DTR Core Team</p>
                                    
                                    '''
                            }
                            }
                            }
                    }
                }
                else{
                    echo "Twistlock scan Failed!"
                    docker.withRegistry('https://blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev', '503302923_Jfrog_RT') {
                                    sh 'docker tag "'+HardenImage+'" blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseTwistlockFailed'
                                    sh 'docker push blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseTwistlockFailed'
                                    sh 'docker rmi -f blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"'+HardenImage+'"_ReleaseTwistlockFailed'
                                }
                    emailext attachLog: true,
                            attachmentsPattern:'Release_TwistlockOutput3.*',

                            to: "503357954@gehealthcare.com",
                            subject: "Release Pipeline |Twistlock Checkpoint Failed|${env.Image_First}",
                            body: 
                            '''
                            
                            </b></p>Job_name=${JOB_NAME}, 
                            </b></p>Build_number=${BUILD_NUMBER}, 
                            </b></p>Build_timestamp=${BUILD_TIMESTAMP},
                                
                                    <table style="border: 1px solid #000000;"> 
                                        <tr><th>HardenImage at Dev Repo</th><td style="border: 1px solid #000000;"> '+HardenImage+'</td></tr>
                                        
                                    </table>
                            <br>
                            </p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p>

                            <p>Regards,<br>DTR Core Team</p>
                            '''

                }
            }
/////&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&////////
                    }

            stage ('Cleanup') {
                    sh '''
			        echo "3 cleanup"
                    pwd
                    id
				    cd ./resources					        
                    chmod a+x ./new_cleanup_copy_2.sh && sudo bash ./new_cleanup_copy_2.sh $Image 
                       
                             
                    ''' 
                    cleanWs()
                        dir("${WORKSPACE}@tmp") {
                            deleteDir()
                            }
                }
}
catch(err) {                    
            stage ('Cleanup') {
                    sh '''
			        echo "4 cleanup"
                    pwd
                    id
				    cd ./resources					        
                    chmod a+x ./new_cleanup_copy_2.sh && sudo bash ./new_cleanup_copy_2.sh $Image 
                       
                             
                    ''' 
                    cleanWs()
                        dir("${WORKSPACE}@tmp") {
                            deleteDir()
                            }
                }
        echo 'Something went wrong! Job has been ended '+ err
		throw err
	}                
}
