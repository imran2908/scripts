import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
import groovy.lang.Binding
import groovy.lang.GroovyShell

def workingDirectory(){
            sh """
                pwd
                id
				cd ./resources/docker-bench
                pwd
                chmod a+x TwistcliScan_Release_test.sh PullExistingImage.sh ReleasePush_test.sh ReleaseCleanup.sh
								
				"""

}
def call(body) {
    def config = [:]
	body.resolveStrategy = Closure.DELEGATE_FIRST
	body.delegate = config
	body()
    echo "Hello World"
	try {
		/*stage("ASBOM") {
					dir(env.WORKSPACE) {
						git branch: "${config.dsl_branch_name}", changelog: false, poll: false, url: "${config.dsl_branch_repo}", credentialsId: "${config.credentialsId}"
					}
		}*/
		stage("Checkout Code") {               
					git branch: 'Hardening-Team-Development',
					url: "git@gitlab-gxp.cloud.health.ge.com:503302923/common-lib-devops.git",
					credentialsId: '503302925_Gitlab'       
		}
		
		stage('Pull Existing Images') {				
					
					sh """
					pwd
					cd ./resources/docker-bench
					chmod a+x ./PullExistingImage.sh && ./PullExistingImage.sh ${HardenImage}
					
					"""
					//sh 'sudo bash /root/Hardening-Team-Development/Release-SingleImage/PullExistingImage.sh $HardenImage'
				}
		stage ('Twistcli Scan') {
				sh """
					cd ./resources/docker-bench
                    pwd
                    id
					chmod a+x ./TwistcliScan_Release_test.sh && ./TwistcliScan_Release_test.sh ${HardenImage}
					
					"""
				
				script {
                    env.Expected_CRITICAL = 0
                    env.Expected_HIGH = 0
                    env.Twistlock_CRITICAL = sh( script: "cd ./resources/docker-bench && cat Release_TwistlockOutput3.log | grep -m1 'Vulnerabilities ' | awk -F, '{print  \$2}' | awk -F '- ' '{print \$NF}'",returnStdout: true).trim()
                    env.Twistlock_HIGH = sh( script: "cd ./resources/docker-bench && cat Release_TwistlockOutput3.log | grep -m1 'Vulnerabilities ' | awk -F, '{print  \$3}' | awk -F '- ' '{print \$NF}'",returnStdout: true).trim()
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
                            //attachmentsPattern:'Release_TwistlockOutput3.*',
                            attachmentsPattern:'resources/docker-bench/Release_TwistlockOutput3.*',

                            to: "212590189@ge.com",
                            //subject: "Release Pipeline | Approval Request: ${HardenImage}|Job_number:${env.BUILD_NUMBER}",
                            subject: "Release Pipeline | Approval Request: ${env.Image_First}|Job_number:${env.BUILD_NUMBER}",
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
                            
                                env.PUSH_IMG = input message: 'Push Image to Release Dev Artifact', ok: 'Continue',
                                //parameters: [extendedChoice(name: 'Push_to_Release', type: 'Check Boxes', value: '$HardenImage'),choice(name: 'Push_Artifact',choices: 'YES\nNO', description: 'push to artifact')]
                                parameters: [choice(name: 'Push_to_Release',choices: 'YES\nNO', description: "HardenImage in Dev: ${HardenImage}")]
                                echo "${env.PUSH_IMG}"
                            }
                            if (env.PUSH_IMG == 'YES'){
                                
                                echo "========== Harden Image to be Pushed to Release Artifactory =============="
                                docker.withRegistry('https://blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/', '503302923_Jfrog_RT') {
                                    sh """
                                        cd ./resources/docker-bench
                                        pwd
                                        id
                                        chmod a+x ./ReleasePush_test.sh && ./ReleasePush_test.sh ${HardenImage}
                                        
                                    """
                                                                                                           
                                }
                                    
                                    
                                emailext attachLog: true,attachmentsPattern:'resources/docker-bench/Release_TwistlockOutput3.*,GE.png,cyblab.png',
                                to: "212590189@ge.com,DevSecOpsDTR@ge.com",
                                subject: "Release Pipeline |Status: Harden Docker Image ${env.Image_First} Pushed to DTR",
                                body: 
                                '''
                                    <table style="border: 1px solid #000000;">
                                    
                                    <img src = "GE.png" alt = "GE Image" style="width: 100%" />
                                    <p align = "center"><b>Docker Trust Registry (DTR) Communication</b></p>
                                    <p>Hello Everyone,</p><br>
                                    </b></p>Job_name=${JOB_NAME}, 
                                    </b></p>Build_number=${BUILD_NUMBER},
                                    </b></p>Build_timestamp=${BUILD_TIMESTAMP},                      
                                    
                                    <p>Harden Image pushed to Release repo. Path to download artifact as follows:</p>
                                    <table style="border: 1px solid #000000;"> 
                                    <tr>${BUILD_LOG_REGEX, regex=".*(ReleaseImage =.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</tr>
                                    </table>
                                    <br>
                                    
                                    </p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p><br>

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
                                docker.withRegistry('https://blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev', '503302923_Jfrog_RT') {
                                        sh 'docker tag "$HardenImage" "$HardenImage"_ReleaseApprovalDenied'
                                        sh 'docker push "$HardenImage"_ReleaseApprovalDenied'
                                        sh 'docker rmi -f "$HardenImage"_ReleaseApprovalDenied'
                                }
                                emailext attachLog: true,attachmentsPattern:'resources/docker-bench/Release_TwistlockOutput3.*',
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
                                    
                                    <p>${BUILD_LOG_REGEX, regex=".*(COMMENTS.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p>
                                    <br>
                                    </p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p>

                                    <p>Regards,<br>DTR Core Team</p>
                                    
                                    '''
                            }
                    }
                }
                else{
                    echo "Twistlock scan Failed!"
                    docker.withRegistry('https://blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev', '503302923_Jfrog_RT') {
                                    sh 'docker tag "$HardenImage" "$HardenImage"_ReleaseTwistlockFailed'
                                    sh 'docker push "$HardenImage"_ReleaseTwistlockFailed'
                                    sh 'docker rmi -f "$HardenImage"_ReleaseTwistlockFailed'
                                }
                    emailext attachLog: true,
                            attachmentsPattern:'resources/docker-bench/Release_TwistlockOutput3.*',

                            to: "212590189@ge.com",
                            subject: "Release Pipeline |Twistlock Checkpoint Failed|${env.Image_First}",
                            body: 
                            '''
                            
                            </b></p>Job_name=${JOB_NAME}, 
                            </b></p>Build_number=${BUILD_NUMBER}, 
                            </b></p>Build_timestamp=${BUILD_TIMESTAMP},
                                
                                    <table style="border: 1px solid #000000;"> 
                                        <tr><th>HardenImage at Dev Repo</th><td style="border: 1px solid #000000;"> ${HardenImage}</td></tr>
                                        
                                    </table>
                            <br>
                            </p>If you have any questions please reach out to DevSecOpsDTRCoreDev@ge.com</p>

                            <p>Regards,<br>DTR Core Team</p>
                            '''
                }
        }
        stage('Release Cleanup') {
                        
                
                sh """
                    cd ./resources/docker-bench
                    pwd
                    id
                    chmod a+x ./ReleaseCleanup.sh && ./ReleaseCleanup.sh ${HardenImage}
                                        
                    """
                
                /*workingDirectory()
                sh 'chmod a+x ./ReleaseCleanup.sh && ./ReleaseCleanup.sh ${HardenImage}'
                sh './ReleaseCleanup.sh ${HardenImage}'
                */
                cleanWs()
            }
	}
    catch(err) {
            stage('Release Cleanup') {
                        
                
                sh """
                    cd ./resources/docker-bench
                    pwd
                    id
                    chmod a+x ./ReleaseCleanup.sh && ./ReleaseCleanup.sh ${HardenImage}
                                        
                    """                
            }
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

            echo 'Something went wrong! Job has been ended '+ err
            throw err
    }

}
