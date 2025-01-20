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

node ('Harden-Base-Image') {

    try{
  
        stage('Git Checkout') {   
                          
                git branch: 'main',
                url: 'git@gitlab-gxp.cloud.health.ge.com:Cyber-Security-Lab/common-lib-devops.git',
                credentialsId: 'hardening_test_30nov'       
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
            	to: "212590189@ge.com,cc:212757368@ge.com",
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

        stage('Base-Image Staging Artifactory Push') {
                docker.withRegistry('https://blr-artifactory.cloud.health.ge.com/docker-cyberlab-stage', '503302923_Jfrog_RT') { 
                sh '''
					        pwd
                            id
					        cd ./resources
					        chmod a+x ./new_BaseImage_Push_copy.sh && ./new_BaseImage_Push_copy.sh $Image 
                    ''' 
                }    
            }

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
					chmod a+x ./new_Posttwistlockscan_skipvulnchk.sh && sudo bash ./new_Posttwistlockscan_skipvulnchk.sh $Image $twistlock_user $twistlock_pass
					
					'''
                    
        }          

                    }                                       

        stage ('Docker Bench Score Validation') {
                sh '''
					        pwd
                            id
					        cd ./resources
					        chmod a+x ./new_CIS_validation_copy.sh && sudo bash ./new_CIS_validation_copy.sh $Image $Threshold
                    '''
 
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
                }
                    if (env.Achieved_CISScore >= env.Threshold_CISScore){    
                        echo "SUCCESS - Docker Bench Threshold Score Achieved!!"                   
                    
//End of Docker Bench score check script

//Start of Notification Script            

                    stage ('Notify Approver') {
                        emailext attachLog: true,
                        attachmentsPattern:'docker-bench/docker-bench-security-1.5.0/DockerBenchOutput1.log,resources/secret.txt,resources/Initial_TwistlockOutput1.log,resources/Post_TwistlockOutput2.log,docker-bench/docker-bench-security-1.5.0/DockerBenchOutput2.log,shellcheck.log',
            	        to: "212590189@ge.com,cc:212757368@ge.com,cc:503302923@ge.com,cc:503335120@ge.com",
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

                        <b><u>Note:</u></b> Requestor is aware that Harden Image contain one or more Critical/High vulnerability. Hence requesting to approve the job.
                        <br>

                        <p>Regards,<br>DTR Core Team</p><br>

                        '''
                    }
                    

try {
    stage('Deploy Approval') {
                        timeout(time:180, unit:'MINUTES') {                            
                            script {
                                def userInput1 = input(id: 'userInput1', message: 'Your input is mandatory to push Golden Image to Artifactory', ok: 'Confirm Selection',  submitter: '212590189,212757368', parameters: [[$class: 'BooleanParameterDefinition', defaultValue: false, description: 'Please left-click once on the checkbox above to put a check mark and hit Confirm button below to invoke artifactory push. Otherwise hit Abort.', name: 'Push Golden Image to blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev/']])
            //echo 'userInput: ' + userInput1
            println(userInput1)
                        
                        if (userInput1 == true){
                            //echo "========== Golden Image to be Pushed Dev Artifactory =============="
							                           
                            stage('Golden Image Push to Artifactory') {
                                docker.withRegistry('https://blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev', '503302923_Jfrog_RT') {
                                sh '''
					            pwd
                                id
					            cd ./resources
					            chmod a+x ./new_HardenImage_Push_copy.sh && sudo bash ./new_HardenImage_Push_copy.sh $Image
                                '''
                            }
                            }                            
                            
							emailext attachLog: true,
                            attachmentsPattern:'',
                            to: "212590189@ge.com,cc:212757368@ge.com",
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
                            </b></p>${BUILD_LOG_REGEX, regex=".*(Untagged: blr-artifactory.cloud.health.ge.com/docker-cyberlab-dev.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}</p></b>
                            </table><br>
                            
				            <p>Regards,<br>DTR Core Team</p><br>
                            '''
                        }
                        else{
                          catchError(buildResult: 'FAILURE', stageResult: 'ABORTED') 
                            {		
                                
                                script{
                                def userInput2 = input(id: 'userInput2', message: 'Are we sure do not want to push Golden Image to Artifactory?', ok: 'Confirm',  submitter: '212590189,212757368', parameters: [[$class: 'TextParameterDefinition', defaultValue: '', description: 'Please add remarks in the textbox below before hitting Confirm button below. Otherwise hit Abort.', name: 'Remarks']])
            //echo 'userInput: ' + userInput2
            println(userInput2)
                                }                             
                            }
                            stage ('Cleanup') {
                    sh '''
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
                }
            }
}
catch (error) {
            stage ('Cleanup') {
                    sh '''
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
                    else {
                        echo "Restricted applied on $Image hence cannot be hardened"
                    }
            stage ('Cleanup') {
                    sh '''
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
