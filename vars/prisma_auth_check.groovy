import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
import groovy.lang.Binding
import groovy.lang.GroovyShell

def call(body) {
    def config = [:]
	body.resolveStrategy = Closure.DELEGATE_FIRST
	body.delegate = config
	body()
    echo "Hello World"


stage('checkout scm') {   
                          
                git branch: 'main',
                url: "git@gitlab-gxp.cloud.health.ge.com:Cyber-Security-Lab/common-lib-devops.git",
                credentialsId: 'hardening_test_30nov'       
            }
stage ('prisma scan') {
	    withCredentials([usernamePassword(credentialsId: 'prisma_cred_for_DTR', passwordVariable: 'twistlock_pass', usernameVariable: 'twistlock_user')]) {
        // some block
        
        sh """
					pwd
                    id
					cd ./resources
					chmod a+x ./prisma_initial_scan.sh && ./prisma_initial_scan.sh $Image $twistlock_user $twistlock_pass
					
					"""

        }
        }
}
