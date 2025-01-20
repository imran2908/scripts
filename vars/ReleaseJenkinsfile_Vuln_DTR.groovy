import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
import groovy.lang.Binding
import groovy.lang.GroovyShell

echo "Build_start_time: ${BUILD_TIMESTAMP}"

def HardenImages = params.HardenImage
DevImage = HardenImages.replace("\n", ",")
echo "${DevImage}"


if (HardenImages.isEmpty()) {
    echo "INPUT MISSING:PLEASE PROVIDE Image"
    emailext attachLog: true,
    to: "212590189@ge.com",
    //subject: "Status: ${currentBuild.result?:'Please Enter the Input Parameters'} - Job \'${env.JOB_NAME}:${env.BUILD_NUMBER}\'",
    subject: "Release Pipeline ,Job_number-${env.BUILD_NUMBER}, ${DevImage},Please Enter the Input Parameters",
				body: 
				    '''
				    </b></p>Job_name=${JOB_NAME}, 
				    </b></p>Build_number=${BUILD_NUMBER}, 
                    <p></b>PARAMETERS:NOT DEFINED. PLEASE PROVIDE INPUT</b></p>
                    </b></p>Image : $DevImage</b></p>
                    </b></p>Threshold : $Threshold</b></p>

                    '''
	return -1
}
else{
    node ('INBLRCYBDTRCHP90') {
        try {	
                
            stage ('clone repository') {
               /// checkout scm
               git branch: 'development',
                ///url: 'git@gitlab-gxp.cloud.health.ge.com:dtr-testing/common-lib-devops.git',
                url: 'git@gitlab.apps.ge-healthcare.net:Cyber-Security-Lab/common-lib-devops.git',
                credentialsId: 'hardening_90'




            }
            stage('Pull Existing Images') {
                ///sh 'sudo bash /root/Hardening-Team-Development/Release-SingleImage/PullExistingImage.sh $HardenImage'
                sh 'chmod a+x ./resources/PullExistingImage.sh && sudo bash ./resources/PullExistingImage.sh $HardenImage'
            }
            stage ('Twistcli Scan') {
                withCredentials([usernamePassword(credentialsId: 'prisma_cred_for_DTR', passwordVariable: 'twistlock_pass', usernameVariable: 'twistlock_user')]) {
               /// sh 'sudo bash /root/Hardening-Team-Development/Release-SingleImage/TwistcliScan_Release_skipvulnchk.sh $HardenImage $twistlock_user $twistlock_pass'
               
                sh 'chmod a+x ./resources/TwistcliScan_Release_skipvulnchk.sh && sudo bash ./resources/TwistcliScan_Release_skipvulnchk.sh $HardenImage $twistlock_user $twistlock_pass'  
                }                
            }

// splitting image_name tag  

            script{
                    String[] split_Image = HardenImage.split('/')
                    String[] split_Image_First = split_Image[2].split('_harden')
                    env.Image_First = split_Image_First[0]
            }
                                
                    stage('Notify Approver'){
                            echo 'Release Twistlock Scan Pass. Approval Mail to be Triggered *****'                              
                            emailext attachLog: true,
                            attachmentsPattern:'Release_TwistlockOutput3.*',

                            to: "212590189@ge.com,cc:212757368@ge.com",
                            subject: "[${env.BUILD_NUMBER}] Release Pipeline | Approval Request | ${env.Image_First}",
                            body: 
                                '''
                                </b></p>Job_name=${JOB_NAME}, 
                                </b></p>Build_number=${BUILD_NUMBER},
                                </b></p>Build_timestamp=${BUILD_TIMESTAMP},
                                
                                <table style="border: 1px solid #000000;"> 
                                    <tr><th>HardenImage at Dev</th><td style="border: 1px solid #000000;"> ${HardenImage}</td></tr>
                                </table>
                                <br>
                                </p><b>Post Harden Twistlock Scan</b></p>
                                </p><b>================================================================================================================</b></p>
                                </p>${BUILD_LOG_REGEX, regex=".*(Vulnerabilities found.*low - [0-9]*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p>
                                </p>${BUILD_LOG_REGEX, regex=".*(Compliance found.*low - [0-9]*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p><br>

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
                                //parameters: [extendedChoice(name: 'Push_to_Release', type: 'Check Boxes', value: '$HardenImage'),choice(name: 'Push_Artifact',choices: 'YES\nNO', description: 'push to artifact')]
                                //parameters: [choice(name: 'Push_to_Release',choices: 'YES\nNO', description: "HardenImage in Dev: ${HardenImage}")]
                                //echo "${env.PUSH_IMG}"
                                def userInput1 = input(id: 'userInput1', message: 'Your input is mandatory to push Golden Image to Artifactory', ok: 'Confirm Selection', parameters: [[$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Please left-click once on the checkbox above to put a check mark and hit Confirm button below to invoke artifactory push. Otherwise hit Abort.', name: 'Push Golden Image to blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-release/']])
            //echo 'userInput: ' + userInput1
            println(userInput1)
                            
                            //if (env.PUSH_IMG == 'YES')
                            if (userInput1 == true){
                                echo "========== Harden Image to be Pushed to Release Artifactory =============="
                                docker.withRegistry('https://blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-release/', '503302923_Jfrog_RT') {
                                   /// sh 'sudo bash /root/Hardening-Team-Development/Release-SingleImage/ReleasePush_reboot.sh $HardenImage'
                                   sh 'chmod a+x ./resources/ReleasePush_reboot.sh && sudo bash ./resources/ReleasePush_reboot.sh $HardenImage'
                                                                       
                                }
                                    
                                    
                            //    emailext attachLog: false,attachmentsPattern:'Release_TwistlockOutput3.*,DTR_comms_new_header1.png,cyblab.png',
                                emailext attachLog: false,attachmentsPattern:'Release_TwistlockOutput3.*,DTR_comms_new_header1.png',
                                to: "DevSecOpsDTR@ge.com,cc:DevSecOpsDTRCoreDev@ge.com",
                                subject: "[${env.BUILD_NUMBER}] DTR Release Info | Harden Docker Image '${env.Image_First}' Pushed to DTR",
                                body: 
                                '''
                                    <table style="border: 1px solid #000000;">
                                    
                                    <img src = "DTR_comms_new_header1.png" alt = "GE Image" style="width: 100%" />
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
                                                                        
                                    </p><b><u>Important Note:</u></b><br>Aforementioned Harden Image could contain vulnerable component with Critical or High severity.<br>Refer to attached Vulnerability Assessment for more details.</p>
                                    
                                    <br></p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p><br>

                                    <p>Regards,<br>DTR Core Team</p>
                                  
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
                                        sh 'docker tag "$HardenImage" blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"$HardenImage"_ReleaseApprovalDenied'
                                        sh 'docker push blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"$HardenImage"_ReleaseApprovalDenied'
                                        sh 'docker rmi -f blr-artifactory.apps.ge-healthcare.net/docker-cyberlab-dev/"$HardenImage"_ReleaseApprovalDenied'
                                }
                                emailext attachLog: true,attachmentsPattern:'Release_TwistlockOutput3.*',
                                to: "212590189@ge.com",
                                subject: "Status: ${currentBuild.result?:'Approval Declined'} - Job \'${env.JOB_NAME}:${env.BUILD_NUMBER}\'",
                                body: 
                                    '''
                                    </p>Job_name=${JOB_NAME}, 
                                    </b></p>Build_number=${BUILD_NUMBER},
                                    </b></p>Build_timestamp=${BUILD_TIMESTAMP},
                                
                                    <table style="border: 1px solid #000000;"> 
                                        <tr><th>HardenImage at Dev Repo</th><td style="border: 1px solid #000000;"> ${HardenImage}</td></tr>
                                        
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
            
            stage(' Cleanup') {
                        
               /// sh 'sudo bash /root/Hardening-Team-Development/Release-SingleImage/ReleaseCleanup.sh $HardenImage'
               sh 'chmod a+x ./resources/ReleaseCleanup.sh && sudo bash ./resources/ReleaseCleanup.sh $HardenImage'


                cleanWs()
                dir("${env.WORKSPACE}@tmp") {
                                deleteDir()
                            }
            }                                
        }

        catch(err) {
            stage(' Cleanup') {

                
            
            emailext attachLog: true,attachmentsPattern:'Release_TwistlockOutput3.*',
            to: "212590189@ge.com",
            subject: "Release Pipeline |Status: Aborted/Unsuccessful",
            body: 
                '''
                </b></p>Job_name=${JOB_NAME}, 
                </b></p>Build_number=${BUILD_NUMBER},
                </b></p>Build_timestamp=${BUILD_TIMESTAMP},                      
                                    
                <table style="border: 1px solid #000000;"> 
                <tr><th>HardenImage at Dev Repo</th><td style="border: 1px solid #000000;"> ${HardenImage}</td></tr>                        
                </table>

                <p>Kindly check attached build.log file.</p>
                                    
                </p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p><br>

                <p>Regards,<br>DTR Core Team</p>
                                                                    
                ''' 
             ///   sh 'sudo bash /root/Hardening-Team-Development/Release-SingleImage/ReleaseCleanup.sh $HardenImage'
             sh 'chmod a+x ./resources/ReleaseCleanup.sh && sudo bash ./resources/ReleaseCleanup.sh $HardenImage'
                cleanWs()
                dir("${env.WORKSPACE}@tmp") {
                                deleteDir()
                            }

            echo 'Something went wrong! Job has been ended '+ err
            throw err
            }
        }
    }
}
