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

    
  
        stage('Git Checkout') {   
                          
                git branch: 'development',
                url: 'git@gitlab.apps.ge-healthcare.net:Cyber-Security-Lab/common-lib-devops.git',
                credentialsId: 'hardening_90'       
            }


        stage ('OCI Check') {
                sh '''
					pwd
                    id
					cd ./resources
					chmod a+x ./CIS_test_kanu.sh && ./CIS_test_kanu.sh $Image > ${WORKSPACE}/ocicheck.txt
					
					'''
        }

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
        }
