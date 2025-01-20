/*import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
import groovy.lang.Binding
import groovy.lang.GroovyShell
import java.lang.*

def call(body) {
    def config = [:]
	body.resolveStrategy = Closure.DELEGATE_FIRST
	body.delegate = config
	body()
    def twistlockusr = config.usr_twistlock
	def twistlockpswd = config.pswd_twistlock
    echo "Hello World"
    echo "Build_start_time: ${BUILD_TIMESTAMP}"

    def Images = params.Image
    dockerImage = Images.replace("\n", ",")
    echo "Image: ${dockerImage}"
    def Hardening_score = params.Threshold
    echo "CIS_benchmark Threshold: ${Hardening_score}"*/
    
node ('Harden-Base-Image') {
            
            stage("Checkout Code") {   
                sh 'id'
                sh 'pwd'          
                git branch: 'main',
                url: "git@gitlab-gxp.cloud.health.ge.com:Cyber-Security-Lab/common-lib-devops.git",
                credentialsId: 'hardening_test_30nov'       
            }
            /*stage ('Twistcli Dockerbench Initial Scan') {
	            
                sh """
					pwd
                    id
					cd ./resources/docker-bench
					chmod a+x ./twistcli_dockerbench_initial_scan.sh && ./twistcli_dockerbench_initial_scan.sh ${Image}
					
					"""
                emailext attachLog: false,
                attachmentsPattern:'resources/docker-bench/Initial_TwistlockOutput1.log,resources/docker-bench/DockerBenchOutput1.log',

            	to: "503302925@ge.com",
                subject: "Container Hardening Pipeline: Pre-Harden TWISTLOCK SCAN REPORT|Job_number:${env.BUILD_NUMBER}|${Image}",
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
                    ${BUILD_LOG_REGEX, regex=".*(Packages to install.*).*", linesBefore=0, linesAfter=0, maxMatches=1, showTruncatedLines=false, escapeHtml=true, matchedLineHtmlStyle=true, substText="$1"}
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
            stage('Base-image Staging Artifact Push') {
                docker.withRegistry('https://blr-artifactory.cloud.health.ge.com/docker-cyberlab-stage', '503302923_Jfrog_RT') { 
                    sh """
					pwd
                    id
					cd ./resources/docker-bench
					chmod a+x ./BaseImage_Push.sh && ./BaseImage_Push.sh ${Image}
					
					"""

                }    
            }*/

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

        }
